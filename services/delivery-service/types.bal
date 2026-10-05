const string TOPIC_ORDER_STATUS_CHANGED = "orders.status-changed";
const string TOPIC_DELIVERY_ASSIGNED = "delivery.assigned";
const string TOPIC_DELIVERY_PICKED_UP = "delivery.picked-up";
const string TOPIC_DELIVERY_COMPLETED = "delivery.completed";

// -----Enums-----
public enum DriverStatus {
    AVAILABLE,
    BUSY,
    OFFLINE
}

public enum DeliveryStatus {
    ASSIGNED,
    PICKED_UP,
    DELIVERED
}

// -----Errors (mapped to HTTP codes in service.bal)-----
type ValidationError distinct error;
type NotFoundError distinct error;
type ConflictError distinct error;

//-----Collections-----
type Location record {|
    float lat;
    float lng;
|};

type Driver record {|
    string driverId;
    string name;
    string phone;
    string vehicle;
    DriverStatus status;
    Location? location;
    string updatedAt;
|};

type Delivery record {|
string deliveryId;
string orderId;
string driverId;
string customerId;
string restaurantId;
DeliveryAddress deliveryAddress;
DeliveryStatus status;
string assignedAt;
string? pickedUpAt;
string? deliveredAt;
|};

# An order that was READY when no driver was free.
type PendingDelivery record {|
    string orderId;
    string customerId;
    string restaurantId;
    DeliveryAddress deliveryAddress;
    string queuedAt;
|};

type ProcessedEvent record {|
    string eventId;
    string processedAt;
|};

//----HTTP request / response bodies----
type NewDriver record {|
    string name;
    string phone;
    string vehicle;
|};

type DriverStatusUpdate record {|
    DriverStatus status;
|};

type LocationUpdate record {|
    float lat;
    float lng;
|};

type ErrorBody record {|
    string 'error;
    string message;
    |};
    type EventEnvelope record {|
    string eventId;
    string eventType;
    int version;
    string occurredAt;
    string 'source;
    string orderId;
    json data;
    |};

type DeliveryAddress record {|
    string street;
    string suburb;
    string city;
    float lat;
    float lng;
    |};

    type OrderStatusChangedData record {|
    string customerId;
    string restaurantId;
    string fromStatus;
    string toStatus;
    string reason;
    decimal total;
    DeliveryAddress deliveryAddress;
    |};

    type DeliveryAssignedData record {|
    string deliveryId;
    string driverId;
    string driverName;
    string customerId;
    string restaurantId;
    |};

    type DeliveryPickedUpData record {|
    string deliveryId;
    string driverId;
    string customerId;
    string pickedUpAt;
    |};

    type DeliveryCompletedData record {|
    string deliveryId;
    string driverId;
    string customerId;
    string restaurantId;
    string deliveredAt;
    int durationMinutes;
    |};

