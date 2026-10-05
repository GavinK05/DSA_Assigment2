import ballerina/log;
import ballerina/time;
import ballerinax/kafka;

listener kafka:Listener restaurantKafkaListener = new (kafkaBootstrap, {
    groupId: "restaurant-service",
    topics: ["orders.created", "orders.status-changed"],
    offsetReset: "earliest",
    autoCommit: false,
    pollingInterval: 1
});

service on restaurantKafkaListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) {
        boolean batchSucceeded = true;
        foreach kafka:BytesConsumerRecord kafkaRecord in records {
            string|error payloadResult = string:fromBytes(kafkaRecord.value);
            if payloadResult is error {
                log:printError("Skipping Kafka record with invalid UTF-8", 'error = payloadResult);
                continue;
            }
            json|error jsonResult = payloadResult.fromJsonString();
            if jsonResult is error {
                log:printError("Skipping Kafka record with invalid JSON", 'error = jsonResult);
                continue;
            }
            EventEnvelope|error envelopeResult = jsonResult.cloneWithType();
            if envelopeResult is error {
                log:printError("Skipping Kafka record with an invalid event envelope", 'error = envelopeResult);
                continue;
            }

            EventEnvelope envelope = envelopeResult;
            log:printInfo("consumed", topic = envelope.eventType, orderId = envelope.orderId);

            error? processingResult;
            if envelope.eventType == "orders.created" {
                processingResult = handleOrderCreated(envelope);
            } else if envelope.eventType == "orders.status-changed" {
                processingResult = handleOrderStatusChanged(envelope);
            } else {
                log:printError("Skipping message with an unsupported event type", eventType = envelope.eventType);
                continue;
            }
            if processingResult is error {
                log:printError("Restaurant event processing failed; offsets were not committed",
                    'error = processingResult,
                    topic = envelope.eventType,
                    orderId = envelope.orderId
                );
                batchSucceeded = false;
                break;
            }
        }

        if batchSucceeded {
            error? commitResult = caller->commit();
            if commitResult is error {
                log:printError("Failed to commit restaurant consumer offsets", 'error = commitResult);
            }
        }
    }
}

# Validates a new order, reserves its stock, persists the kitchen view, and publishes the pricing result.
# + envelope - Event envelope received from the order service.
# + return - An error if validation dependencies or side effects fail.
public function handleOrderCreated(EventEnvelope envelope) returns error? {
    boolean alreadyProcessed = check isEventProcessed(envelope.eventId);
    if alreadyProcessed {
        return ();
    }

    OrderCreatedData|error dataResult = envelope.data.cloneWithType();
    if dataResult is error {
        return dataResult;
    }
    OrderCreatedData data = dataResult;

    KitchenOrder|error existingOrderResult = findKitchenOrder(data.restaurantId, envelope.orderId);
    if existingOrderResult is KitchenOrder {
        // The order document is the durable evidence that its stock was already reserved.
        OrderValidationResult savedValidation = {
            accepted: existingOrderResult.status != "REJECTED",
            reason: "",
            items: existingOrderResult.items,
            total: existingOrderResult.total,
            currency: "NAD"
        };
        check publishOrderValidated(envelope.orderId, data.restaurantId, data.customerId, savedValidation);
        return markEventProcessed(envelope.eventId, envelope.eventType, time:utcToString(time:utcNow()));
    }
    if existingOrderResult.message() != "ORDER_NOT_FOUND" {
        return existingOrderResult;
    }

    OrderValidationResult validation = check validateAndPriceOrder(data.restaurantId, data.items);
    if validation.accepted {
        KitchenOrderItem[] reservedItems = [];
        foreach KitchenOrderItem item in validation.items {
            error? reserveResult = reserveStock(data.restaurantId, item.itemId, item.quantity);
            if reserveResult is error {
                if reserveResult.message() == "OUT_OF_STOCK" || reserveResult.message() == "ITEM_NOT_FOUND" {
                    check releaseReservedItems(data.restaurantId, reservedItems);
                    validation = rejectedOrder("OUT_OF_STOCK: " + item.itemId);
                    break;
                }
                check releaseReservedItems(data.restaurantId, reservedItems);
                return reserveResult;
            }
            reservedItems.push(item);
        }

        if validation.accepted {
            string now = time:utcToString(time:utcNow());
            KitchenOrder kitchenOrder = {
                orderId: envelope.orderId,
                restaurantId: data.restaurantId,
                items: validation.items,
                total: validation.total,
                status: "AWAITING_CONFIRMATION",
                receivedAt: now,
                updatedAt: now
            };
            error? saveResult = upsertKitchenOrder(kitchenOrder);
            if saveResult is error {
                check releaseReservedItems(data.restaurantId, reservedItems);
                return saveResult;
            }
        }
    }

    check publishOrderValidated(envelope.orderId, data.restaurantId, data.customerId, validation);
    return markEventProcessed(envelope.eventId, envelope.eventType, time:utcToString(time:utcNow()));
}

# Adds confirmed orders to the kitchen queue and releases reserved stock for cancelled orders.
# + envelope - Status-change event envelope received from the order service.
# + return - An error if persistence or stock release fails.
public function handleOrderStatusChanged(EventEnvelope envelope) returns error? {
    boolean alreadyProcessed = check isEventProcessed(envelope.eventId);
    if alreadyProcessed {
        return ();
    }

    OrderStatusChangedData|error dataResult = envelope.data.cloneWithType();
    if dataResult is error {
        return dataResult;
    }
    OrderStatusChangedData data = dataResult;

    if data.toStatus == "CONFIRMED" {
        KitchenOrder|error orderResult = findKitchenOrder(data.restaurantId, envelope.orderId);
        if orderResult is error {
            if orderResult.message() == "ORDER_NOT_FOUND" {
                log:printError("Confirmed order has no saved restaurant reservation", orderId = envelope.orderId);
                return markEventProcessed(envelope.eventId, envelope.eventType, time:utcToString(time:utcNow()));
            }
            return orderResult;
        }
        if orderResult.status == "AWAITING_CONFIRMATION" {
            _ = check updateKitchenOrderStatus(
                data.restaurantId,
                envelope.orderId,
                "AWAITING_CONFIRMATION",
                "CONFIRMED",
                time:utcToString(time:utcNow())
            );
        }
    } else if data.toStatus == "CANCELLED" {
        KitchenOrder|error orderResult = findKitchenOrder(data.restaurantId, envelope.orderId);
        if orderResult is error {
            if orderResult.message() == "ORDER_NOT_FOUND" {
                return markEventProcessed(envelope.eventId, envelope.eventType, time:utcToString(time:utcNow()));
            }
            return orderResult;
        }
        // A rejected kitchen order can still have reserved stock from validation.
        if orderResult.status != "CANCELLED" {
            foreach KitchenOrderItem item in orderResult.items {
                check releaseStock(data.restaurantId, item.itemId, item.quantity);
            }
            _ = check updateKitchenOrderStatus(
                data.restaurantId,
                envelope.orderId,
                orderResult.status,
                "CANCELLED",
                time:utcToString(time:utcNow())
            );
        }
    }

    return markEventProcessed(envelope.eventId, envelope.eventType, time:utcToString(time:utcNow()));
}

function releaseReservedItems(string restaurantId, KitchenOrderItem[] items) returns error? {
    foreach KitchenOrderItem item in items {
        check releaseStock(restaurantId, item.itemId, item.quantity);
    }
}
