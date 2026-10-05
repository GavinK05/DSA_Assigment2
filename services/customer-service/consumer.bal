import ballerina/log;
import ballerinax/kafka;

listener kafka:Listener customerKafkaListener = new (kafkaBootstrap, {
    groupId: "customer-service",
    topics: ["orders.created", "orders.status-changed"],
    offsetReset: "earliest",
    autoCommit: false,
    pollingInterval: 1
});

service on customerKafkaListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) {
        boolean batchSucceeded = true;
        foreach kafka:BytesConsumerRecord kafkaRecord in records {
            EventEnvelope|error envelope = parseEnvelope(kafkaRecord.value);
            if envelope is error {
                log:printError("skipping bad Kafka record", 'error = envelope);
                continue;
            }
            log:printInfo("consumed", topic = envelope.eventType, orderId = envelope.orderId);

            error? result;
            if envelope.eventType == "orders.created" {
                result = handleOrderCreated(envelope);
            } else if envelope.eventType == "orders.status-changed" {
                result = handleOrderStatusChanged(envelope);
            } else {
                log:printError("skipping unsupported event type", eventType = envelope.eventType);
                continue;
            }
            if result is error {
                log:printError("event processing failed; offset not committed", 'error = result,
                    topic = envelope.eventType, orderId = envelope.orderId);
                batchSucceeded = false;
                break;
            }
        }
        if batchSucceeded {
            error? commitResult = caller->commit();
            if commitResult is error {
                log:printError("failed to commit offsets", 'error = commitResult);
            }
        }
    }
}

function parseEnvelope(byte[] value) returns EventEnvelope|error {
    string payload = check string:fromBytes(value);
    json parsed = check payload.fromJsonString();
    return parsed.cloneWithType();
}

# Records a new order in the customer's history (status CREATED).
# + envelope - orders.created event.
# + return - An error if saving fails.
public function handleOrderCreated(EventEnvelope envelope) returns error? {
    if check isEventProcessed(envelope.eventId) {
        return;
    }
    OrderCreatedData data = check envelope.data.cloneWithType();
    check upsertOrderHistory({
        orderId: envelope.orderId,
        customerId: data.customerId,
        restaurantId: data.restaurantId,
        total: 0d,
        status: "CREATED",
        createdAt: envelope.occurredAt,
        updatedAt: envelope.occurredAt
    }, false);
    check markEventProcessed(envelope.eventId, envelope.eventType);
}

# Updates the status and total of an order in the customer's history.
# + envelope - orders.status-changed event.
# + return - An error if saving fails.
public function handleOrderStatusChanged(EventEnvelope envelope) returns error? {
    if check isEventProcessed(envelope.eventId) {
        return;
    }
    OrderStatusChangedData data = check envelope.data.cloneWithType();
    check upsertOrderHistory({
        orderId: envelope.orderId,
        customerId: data.customerId,
        restaurantId: data.restaurantId,
        total: data.total,
        status: data.toStatus,
        createdAt: envelope.occurredAt,
        updatedAt: envelope.occurredAt
    }, true);
    check markEventProcessed(envelope.eventId, envelope.eventType);
}
