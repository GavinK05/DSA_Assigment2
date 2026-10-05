import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/kafka;

# Kafka producer shared across the order-service. The producer is used to send events to Kafka, e.g. when an order is created or updated. The producer is configured in config.toml with the kafkaBootstrap value.
final kafka:Producer producer = check new (kafkaBootstrap, {acks: kafka:ACKS_ALL});

# wrap data in an envelope and send it.
function publish(string topic, string orderId, json data) returns error? {
    EventEnvelope envelope = {
        eventId: "EVT-" + uuid:createType4AsString(), // type 4 UUID for unique event ID
        eventType: topic,
        version: 1, 
        occurredAt: time:utcToString(time:utcNow()),
        orderId: orderId,
        data: data,
        'source: "order-service"
    };
    check producer->send({topic: topic, key: orderId, value: envelope});
    log:printInfo("published", topic = topic, orderId = orderId);
}

# Publishes order.created for a new order. This is called after the order has been saved to MongoDB successfully.
function publishOrderCreated(Order o) returns error? {
    OrderItem[] items = from OrderLine i in o.items select {itemId: i.itemId, quantity: i.quantity};
        OrderCreatedData data = {
        customerId: o.customerId,
        restaurantId: o.restaurantId,
        items: items,
        deliveryAddress: o.deliveryAddress
    };
    check publish("orders.created", o.orderId, data.toJson());
}

# Publishes orders.status-changed after every transition.
function publishStatusChanged(Order o, OrderStatus previous, string reason) returns error? {
    OrderStatusChangedData data = {
        customerId: o.customerId,
        restaurantId: o.restaurantId,
        fromStatus: previous,
        toStatus: o.status,
        reason: reason,
        total: o.total,
        deliveryAddress: o.deliveryAddress

    };
    check publish("orders.status-changed", o.orderId, data.toJson());
}

