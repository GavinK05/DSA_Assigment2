import ballerina/log;
import ballerina/uuid;
import ballerinax/kafka;

final kafka:Producer eventProducer = check new (kafkaBootstrap, {acks: kafka:ACKS_ALL});

# Wraps data in the standard envelope and sends it with key = orderId.
function publishEvent(string topic, string orderId, anydata data) returns error? {
    EventEnvelope event = {
        eventId: "EVT-" + uuid:createType4AsString(),
        eventType: topic,
        version: 1,
        occurredAt: nowUtc(),
        'source: SERVICE_NAME,
        orderId,
        data: data.toJson()
    };
    check eventProducer->send({
        topic,
        key: orderId.toBytes(),
        value: event.toJsonString().toBytes()
    });
    log:printInfo("published", topic = topic, orderId = orderId, eventId = event.eventId);
}

# Publishes delivery.assigned.
function publishAssigned(Delivery delivery, string driverName) returns error? {
    DeliveryAssignedData data = {
        deliveryId: delivery.deliveryId,
        driverId: delivery.driverId,
        driverName,
        customerId: delivery.customerId,
        restaurantId: delivery.restaurantId
    };
    check publishEvent(TOPIC_DELIVERY_ASSIGNED, delivery.orderId, data);
}

# Publishes delivery.picked-up.
function publishPickedUp(Delivery delivery) returns error? {
    DeliveryPickedUpData data = {
        deliveryId: delivery.deliveryId,
        driverId: delivery.driverId,
        customerId: delivery.customerId,
        pickedUpAt: delivery.pickedUpAt ?: nowUtc()
    };
    check publishEvent(TOPIC_DELIVERY_PICKED_UP, delivery.orderId, data);
}

# Publishes delivery.completed.
function publishCompleted(Delivery delivery, int durationMinutes) returns error? {
    DeliveryCompletedData data = {
        deliveryId: delivery.deliveryId,
        driverId: delivery.driverId,
        customerId: delivery.customerId,
        restaurantId: delivery.restaurantId,
        deliveredAt: delivery.deliveredAt ?: nowUtc(),
        durationMinutes
    };
    check publishEvent(TOPIC_DELIVERY_COMPLETED, delivery.orderId, data);
}
