// Response shapes for the REST API.

public type HealthResponse record {|
    string status;
    string 'service;
|};

public type ErrorResponse record {|
    string 'error;
    string message;
|};

// Stored shapes (match the README collections).

public type RestaurantStat record {|
    string restaurantId;
    int totalOrders;
    int delivered;
    int cancelled;
    decimal revenue;
|};

public type DriverStat record {|
    string driverId;
    int completed;
    int totalMinutes;
|};

public type OrderStat record {|
    string status;
    int count;
|};

public type PaymentStat record {|
    string status;
    int count;
    decimal amount;
|};

public type ProcessedEvent record {|
    string eventId;
    string eventType;
    string processedAt;
|};

// Report shapes.

public type OrdersReport record {|
    OrderStat[] byStatus;
    int totalOrders;
    decimal totalRevenue;
|};

public type DriverReportRow record {|
    string driverId;
    int completed;
    int totalMinutes;
    decimal averageMinutes;
|};

public type PaymentBucket record {|
    int count;
    decimal amount;
|};

public type PaymentsReport record {|
    PaymentBucket success;
    PaymentBucket failed;
|};

// Kafka event shapes (copied from contracts/events.bal).

public type EventEnvelope record {|
    string eventId;
    string eventType;
    int version;
    string occurredAt;
    string 'source;
    string orderId;
    json data;
|};

public type DeliveryAddress record {|
    string street;
    string suburb;
    string city;
    decimal lat;
    decimal lng;
|};

public type OrderItem record {|
    string itemId;
    int quantity;
|};

public type OrderCreatedData record {|
    string customerId;
    string restaurantId;
    OrderItem[] items;
    DeliveryAddress deliveryAddress;
|};

public type OrderStatusChangedData record {|
    string customerId;
    string restaurantId;
    string fromStatus;
    string toStatus;
    string reason;
    decimal total;
    DeliveryAddress deliveryAddress;
|};

public type PaymentCompletedData record {|
    string paymentId;
    string customerId;
    decimal amount;
    string currency;
    string method;
|};

public type PaymentFailedData record {|
    string paymentId;
    string customerId;
    decimal amount;
    string reason;
|};

public type DeliveryAssignedData record {|
    string deliveryId;
    string driverId;
    string driverName;
    string customerId;
    string restaurantId;
|};

public type DeliveryCompletedData record {|
    string deliveryId;
    string driverId;
    string customerId;
    string restaurantId;
    string deliveredAt;
    int durationMinutes;
|};
