# Wraps every Kafka message on every topic with a common envelope. This is useful for event sourcing and event-driven architectures. 
public type EventEnvelope record {| 
    string eventId; 
    string eventType;
    int version;
    string occurredAt; 
    string 'source ;
    string orderId; 
    json data; 
|};

# Delivery address, used by orders.created and orders.status-changed.
public type Address record {|
    string street;
    string suburb;
    string city;
    float lat;
    float lng;
|};

# Every status an order can be in (README 4.3).
public enum OrderStatus {
    CREATED,
    CONFIRMED,
    PREPARING,
    READY,
    OUT_FOR_DELIVERY,
    DELIVERED,
    CANCELLED
}

# Extra restaurant status (PREPARING and READY already exist above).
public const REJECTED = "REJECTED";

# Status the restaurant reports in restaurant.order-updated.
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
    string reason; // reason for the status change, e.g. "Kitchen marked ready"
    decimal total;
    Address deliveryAddress;
|};

# Data for the restaurant.order-validated event.
public type OrderValidatedData record {|
    string restaurantId;
    string customerId;
    boolean accepted;
    string reason;
    PricedItem[] items;
    decimal total;
    string currency;
|};

# Data for the restaurant.order-updated event.
public type RestaurantOrderUpdatedData record {|
    string restaurantId;
    RestaurantStatus status;
|};

# Data for the payments.completed event.
public type PaymentCompletedData record {|
    string paymentId;
    string customerId;
    decimal amount;
    string currency;
    string method; // how the customer paid, e.g. "CARD"
|};
