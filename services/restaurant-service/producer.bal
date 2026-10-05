import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/kafka;

// we keep one producer and reuse it for both restaurant topics.
kafka:Producer? kafkaProducer = ();

function getKafkaProducer() returns kafka:Producer|error {
    if kafkaProducer is kafka:Producer {
        return <kafka:Producer>kafkaProducer;
    }

    kafka:ProducerConfiguration producerConfiguration = {
        clientId: "restaurant-service",
        acks: kafka:ACKS_ALL,
        retryCount: 3
    };
    kafka:Producer producer = check new (kafkaBootstrap, producerConfiguration);
    kafkaProducer = producer;
    return producer;
}

# Publishes the order validation result to the order, payment, and notification services.
# + orderId - ID used as the event key and envelope order ID.
# + restaurantId - Restaurant that priced or rejected the order.
# + customerId - Customer associated with the order.
# + validation - Accepted/rejected result, priced items, and total.
# + return - An error if the Kafka publish fails.
public function publishOrderValidated(
        string orderId,
        string restaurantId,
        string customerId,
        OrderValidationResult validation
) returns error? {
    PricedItem[] pricedItems = [];
    foreach KitchenOrderItem item in validation.items {
        pricedItems.push({
            itemId: item.itemId,
            name: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice
        });
    }
    OrderValidatedData data = {
        restaurantId: restaurantId,
        customerId: customerId,
        items: pricedItems,
        total: validation.total,
        currency: validation.currency,
        reason: validation.reason,
        accepted: validation.accepted
    };
    EventEnvelope envelope = check createEnvelope(
            "restaurant.order-validated",
            orderId,
            data
    );
    log:printInfo("publishing restaurant.order-validated", orderId = orderId, accepted = validation.accepted);
    return sendEvent("restaurant.order-validated", orderId, envelope);
}

# Publishes a kitchen status fact for the order service to apply.
# + orderId - Order whose kitchen status changed.
# + restaurantId - Restaurant reporting the status.
# + status - Kitchen fact to publish.
# + return - An error if the Kafka publish fails.
public function publishOrderUpdated(string orderId, string restaurantId, RestaurantStatus status) returns error? {
    RestaurantOrderUpdatedData data = {
        restaurantId: restaurantId,
        status: status
    };
    EventEnvelope envelope = check createEnvelope(
            "restaurant.order-updated",
            orderId,
            data
    );
    log:printInfo("publishing restaurant.order-updated", orderId = orderId, status = status.toString());
    return sendEvent("restaurant.order-updated", orderId, envelope);
}

function createEnvelope(string eventType, string orderId, json data) returns EventEnvelope|error {
    string eventId = uuid:createType4AsString();
    return {
        eventId: "EVT-" + eventId,
        eventType: eventType,
        version: 1,
        occurredAt: time:utcToString(time:utcNow()),
        'source: "restaurant-service",
        orderId: orderId,
        data: data
    };
}

function sendEvent(string topic, string orderId, EventEnvelope envelope) returns error? {
    kafka:Producer producer = check getKafkaProducer();
    string payload = envelope.toJsonString();
    check producer->send({
        topic: topic,
        key: orderId.toBytes(),
        value: payload.toBytes()
    });
    log:printInfo("published", topic = topic, orderId = orderId);
}
