import ballerina/log;
import ballerinax/kafka;

listener kafka:Listener orderEventsListener = new (kafkaBootstrap, {
    groupId: SERVICE_NAME,
    topics: [TOPIC_ORDER_STATUS_CHANGED],
    offsetReset: kafka:OFFSET_RESET_EARLIEST,
    autoCommit: false
});

service on orderEventsListener {

    # Handles each record on its own so one bad event can't block the rest, then commits.
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            error? result = processRecord(rec.value);
            if result is error {
                log:printError("failed to handle event, skipping", result);
            }
        }
        check caller->commit();
    }
}

# Parses raw bytes into an envelope and hands it to the handler.
function processRecord(byte[] value) returns error? {
    string text = check string:fromBytes(value);
    EventEnvelope event = check text.fromJsonStringWithType();
    check handleOrderStatusChanged(event);
}

# orders.status-changed: when an order becomes READY, find it a driver.
function handleOrderStatusChanged(EventEnvelope event) returns error? {
    if check isEventProcessed(event.eventId) {
        return;
    }
    log:printInfo("consumed", topic = TOPIC_ORDER_STATUS_CHANGED, orderId = event.orderId, eventId = event.eventId);

    OrderStatusChangedData data = check event.data.cloneWithType();
    if data.toStatus == "READY" {
        check assignDriver(event.orderId, data.customerId, data.restaurantId, data.deliveryAddress);
    }
    check markEventProcessed(event.eventId);
}
