import ballerina/log;
import ballerinax/kafka;

listener kafka:Listener adminKafkaListener = new (kafkaBootstrap, {
    groupId: "admin-service",
    topics: [
        "orders.created",
        "orders.status-changed",
        "payments.completed",
        "payments.failed",
        "delivery.assigned",
        "delivery.completed"
    ],
    offsetReset: "earliest",
    autoCommit: false,
    pollingInterval: 1
});

service on adminKafkaListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) {
        boolean batchSucceeded = true;
        foreach kafka:BytesConsumerRecord kafkaRecord in records {
            EventEnvelope|error envelope = parseEnvelope(kafkaRecord.value);
            if envelope is error {
                log:printError("skipping bad Kafka record", 'error = envelope);
                continue;
            }
            log:printInfo("consumed", topic = envelope.eventType, orderId = envelope.orderId);

            error? result = dispatch(envelope);
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

function dispatch(EventEnvelope envelope) returns error? {
    match envelope.eventType {
        "orders.created" => {
            return handleOrderCreated(envelope);
        }
        "orders.status-changed" => {
            return handleOrderStatusChanged(envelope);
        }
        "payments.completed" => {
            return handlePaymentCompleted(envelope);
        }
        "payments.failed" => {
            return handlePaymentFailed(envelope);
        }
        "delivery.assigned" => {
            return handleDeliveryAssigned(envelope);
        }
        "delivery.completed" => {
            return handleDeliveryCompleted(envelope);
        }
    }
    log:printError("skipping unsupported event type", eventType = envelope.eventType);
}

# Counts a new order for its restaurant and in the CREATED bucket.
# + envelope - orders.created event.
# + return - An error if saving fails.
public function handleOrderCreated(EventEnvelope envelope) returns error? {
    if check isEventProcessed(envelope.eventId) {
        return;
    }
    OrderCreatedData data = check envelope.data.cloneWithType();
    check incrementRestaurantStat(data.restaurantId, orders = 1);
    check incrementOrderStat("CREATED", 1);
    check markEventProcessed(envelope.eventId, envelope.eventType);
}

# Moves the order between status buckets and records delivered/cancelled/revenue.
# + envelope - orders.status-changed event.
# + return - An error if saving fails.
public function handleOrderStatusChanged(EventEnvelope envelope) returns error? {
    if check isEventProcessed(envelope.eventId) {
        return;
    }
    OrderStatusChangedData data = check envelope.data.cloneWithType();
    check incrementOrderStat(data.fromStatus, -1);
    check incrementOrderStat(data.toStatus, 1);
    if data.toStatus == "DELIVERED" {
        check incrementRestaurantStat(data.restaurantId, delivered = 1, revenue = data.total);
    } else if data.toStatus == "CANCELLED" {
        check incrementRestaurantStat(data.restaurantId, cancelled = 1);
    }
    check markEventProcessed(envelope.eventId, envelope.eventType);
}

# Adds a successful payment to the SUCCESS totals.
# + envelope - payments.completed event.
# + return - An error if saving fails.
public function handlePaymentCompleted(EventEnvelope envelope) returns error? {
    if check isEventProcessed(envelope.eventId) {
        return;
    }
    PaymentCompletedData data = check envelope.data.cloneWithType();
    check incrementPaymentStat("SUCCESS", data.amount);
    check markEventProcessed(envelope.eventId, envelope.eventType);
}

# Adds a failed payment to the FAILED totals.
# + envelope - payments.failed event.
# + return - An error if saving fails.
public function handlePaymentFailed(EventEnvelope envelope) returns error? {
    if check isEventProcessed(envelope.eventId) {
        return;
    }
    PaymentFailedData data = check envelope.data.cloneWithType();
    check incrementPaymentStat("FAILED", data.amount);
    check markEventProcessed(envelope.eventId, envelope.eventType);
}

# Makes sure the assigned driver appears in the delivery report.
# + envelope - delivery.assigned event.
# + return - An error if saving fails.
public function handleDeliveryAssigned(EventEnvelope envelope) returns error? {
    if check isEventProcessed(envelope.eventId) {
        return;
    }
    DeliveryAssignedData data = check envelope.data.cloneWithType();
    check incrementDriverStat(data.driverId);
    check markEventProcessed(envelope.eventId, envelope.eventType);
}

# Adds a completed delivery and its duration to the driver's stats.
# + envelope - delivery.completed event.
# + return - An error if saving fails.
public function handleDeliveryCompleted(EventEnvelope envelope) returns error? {
    if check isEventProcessed(envelope.eventId) {
        return;
    }
    DeliveryCompletedData data = check envelope.data.cloneWithType();
    check incrementDriverStat(data.driverId, completed = 1, minutes = data.durationMinutes);
    check markEventProcessed(envelope.eventId, envelope.eventType);
}
