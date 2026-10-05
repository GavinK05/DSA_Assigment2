import ballerina/log;
import ballerinax/kafka;

listener kafka:Listener orderListener = new (kafkaBootstrap, {
    groupId: "order-service",
    topics: [
        "restaurant.order-validated", "restaurant.order-updated",
        "payments.completed", "payments.failed",
        "delivery.assigned", "delivery.picked-up", "delivery.completed"
    ],
    offsetReset: kafka:OFFSET_RESET_EARLIEST,
    autoCommit: false
});

service on orderListener {
    remote function onConsumerRecord(kafka:Caller caller, EventEnvelope[] events) returns error? {
        foreach EventEnvelope e in events {
            error? result = handleEvent(e);
            if result is error {
                log:printError("event skipped", result, eventId = e.eventId, topic = e.eventType);
            }
        }
        check caller->'commit();
    }
}

function handleEvent(EventEnvelope e) returns error? {
    if check isEventProcessed(e.eventId) {
        log:printInfo("duplicate skipped", eventId = e.eventId);
        return;
    }
    log:printInfo("consumed", topic = e.eventType, orderId = e.orderId);

    match e.eventType {
        "restaurant.order-validated" => {
            OrderValidatedData d = check e.data.cloneWithType();
            if d.accepted {
                check setFields(e.orderId, {total: d.total, currency: d.currency, items: d.items.toJson()});
            } else {
                _ = check changeStatus(e.orderId, CANCELLED, d.reason);
            }
        }
        "restaurant.order-updated" => {
            RestaurantOrderUpdatedData d = check e.data.cloneWithType();
            if d.status == PREPARING {
                _ = check changeStatus(e.orderId, PREPARING, "Kitchen started");
            } else if d.status == READY {
                _ = check changeStatus(e.orderId, READY, "Kitchen marked ready");
            } else {
                _ = check changeStatus(e.orderId, CANCELLED, "Restaurant rejected");
            }
        }
        "payments.completed" => {
            _ = check changeStatus(e.orderId, CONFIRMED, "Payment completed");
        }
        "payments.failed" => {
            PaymentFailedData d = check e.data.cloneWithType();
            _ = check changeStatus(e.orderId, CANCELLED, d.reason);
        }
        "delivery.assigned" => {
            DeliveryAssignedData d = check e.data.cloneWithType();
            check setFields(e.orderId, {driverId: d.driverId});
        }
        "delivery.picked-up" => {
            _ = check changeStatus(e.orderId, OUT_FOR_DELIVERY, "Driver picked up"); 
        }
        "delivery.completed" => {
            _ = check changeStatus(e.orderId, DELIVERED, "Delivered");
        }
    }
    check markEventProcessed(e.eventId);
}

// autoCommit: false plus caller-> 'commit() afte processing: an event only counts as done after it's saved, which gives at-least-once delivery.
//isEventProcessed / markEventProcessed: duplicates are skipped, which is idempotency.
//The foreach with if result is error: a bad event is logged and skipped, and the consumer never crashes.
//Every status change goes through changeStatus, so the state machine still blocks invalid moves coming from Kafka.
//'commit has the quote because commit is a reserved word.