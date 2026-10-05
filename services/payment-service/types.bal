# Wraps every Kafka message on every topic with a common envelope. This is useful for event sourcing and event-driven architectures.
public type EventEnvelope record {|
    string eventId;
    string eventType;
    int version;
    string occurredAt;
    string 'source;
    string orderId;
    json data;
|};

# Delivery address, used by orders.created and orders.status-changed events.
public type Address record {|
    string street;
    string suburb;
    string city;
    float lat; // coordinates for the delivery address.
    float lng;
|};

# Order status found in README.md documentation, section 4.3.
public enum OrderStatus { // enum is a "fixed list of allowed values."
    // Only the 7 valid states from the state machine can exist, so an invalid status is a compile error, not a runtime error.
    CREATED,
    CONFIRMED,
    PREPARING,
    READY,
    OUT_FOR_DELIVERY,
    DELIVERED,
    CANCELLED
}

# Extra constant for the restaurant status (PREPARING and READY already exist above).
public const REJECTED = "REJECTED";

# Status the restaurant reports in restaurant.order-updated events.
public type RestaurantStatus PREPARING|READY|REJECTED;

# One item in a new order (no price yet).
public type OrderItem record {|
    string itemId;
    int quantity;
|};

# An item after the restaurant has priced it.
public type PricedItem record {|
    string itemId;
    string name;
    int quantity;
    decimal unitPrice;
|};

# Data for the orders.created event.
public type OrderCreatedData record {|
    string customerId;
    string restaurantId;
    OrderItem[] items;
    Address deliveryAddress;
|};

# Data for the orders.status-changed event.
public type OrderStatusChangedData record {|
    string customerId;
    string restaurantId;
    OrderStatus fromStatus;
    OrderStatus toStatus;
    string reason; // reason for the status change, e.g. "restaurant rejected the order"
    decimal total;
    Address deliveryAddress;
|};

# Data for the restaurant.order-updated event.
public type RestaurantOrderUpdatedData record {|
    string restaurantId;
    RestaurantStatus status;
|};

# Data for the restaurant.order-validated event.
public type OrderValidatedData record {|
    string restaurantId;
    string customerId;
    PricedItem[] items;
    decimal total;
    string currency;
    string reason; // reason for the validation result, e.g. "OUT_OF_STOCK: ITM-..." (empty if accepted)
    boolean accepted; // true if the order is accepted, false if rejected.
|};

# Data for the payments.completed event.
public type PaymentCompletedData record {|
    string paymentId;
    string customerId;
    decimal amount;
    string currency;
    string method; // how the customer paid, e.g. "CARD"
|};

# Data for the payments.failed event.
public type PaymentFailedData record {|
    string paymentId;
    string customerId;
    string reason; // why the payment failed, e.g. "CARD_DECLINED"
    decimal amount;
|};

# Data for the delivery.assigned event.
public type DeliveryAssignedData record {|
    string driverName;
    string driverId;
    string customerId;
    string restaurantId;
    string deliveryId;
|};

# Data for the delivery.picked-up event.
public type DeliveryPickedUpData record {|
    string deliveryId;
    string driverId;
    string customerId;
    string pickedUpAt; // when the driver collected the order (ISO timestamp)
|};

# Data for the delivery.completed event.
public type DeliveryCompletedData record {|
    string deliveryId;
    string driverId;
    string customerId;
    string restaurantId;
    string deliveredAt; // when the order was delivered (ISO timestamp)
    int durationMinutes;
|};

# The result of processing a payment.
public enum PaymentStatus {
    SUCCESS,
    FAILED
}

# A payment as stored in MongoDB.
public type Payment record {|
    string paymentId;
    string orderId;
    string customerId;
    decimal amount;
    string currency;
    string method;
    PaymentStatus status;
    string reason;
    string processedAt;
|};

# Records which Kafka events this service has already handled.
public type ProcessedEvent record {|
    string eventId;
    string processedAt;
|};

# Standard error body returned by the HTTP API.
public type ErrorBody record {|
    string 'error;
    string message;
|};