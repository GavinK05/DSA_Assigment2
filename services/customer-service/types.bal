// Request and response shapes for the REST API.

public type HealthResponse record {|
    string status;
    string 'service;
|};

public type ErrorResponse record {|
    string 'error;
    string message;
|};

public type CustomerCreateRequest record {|
    string name;
    string email;
    string phone;
|};

// name and phone are both optional so a client can update just one of them.
public type CustomerUpdateRequest record {|
    string name?;
    string phone?;
|};

public type AddressRequest record {|
    string label;
    string street;
    string suburb;
    string city;
    decimal lat;
    decimal lng;
|};

// Stored shapes (match the README collections).

public type Address record {|
    string addressId;
    string label;
    string street;
    string suburb;
    string city;
    decimal lat;
    decimal lng;
|};

public type Customer record {|
    string customerId;
    string name;
    string email;
    string phone;
    Address[] addresses;
    string createdAt;
|};

public type OrderHistoryEntry record {|
    string orderId;
    string customerId;
    string restaurantId;
    decimal total;
    string status;
    string createdAt;
    string updatedAt;
|};

public type ProcessedEvent record {|
    string eventId;
    string eventType;
    string processedAt;
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
