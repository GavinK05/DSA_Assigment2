//used enum so the values of the type are rstricted to the values in the enum
// kinda like what we did in assignment 1 with the grpc in propertyStatus
public enum Day {
    MONDAY,
    TUESDAY,
    WEDNESDAY,
    THURSDAY,
    FRIDAY,
    SATURDAY,
    SUNDAY
}

public enum KitchenOrderStatus {
    AWAITING_CONFIRMATION,
    CONFIRMED,
    PREPARING,
    READY,
    REJECTED,
    CANCELLED
}

public enum OrderStatus {
    CREATED,
    CONFIRMED,
    PREPARING,
    READY,
    OUT_FOR_DELIVERY,
    DELIVERED,
    CANCELLED
}

public type DeliveryAddress record {|
    string street;
    string suburb;
    string city;
    float lat;
    float lng;
|};

public type OrderCreatedData record {|
    string customerId;
    string restaurantId;
    OrderItemRequest[] items;
    DeliveryAddress deliveryAddress;
|};

public type OrderStatusChangedData record {|
    string customerId;
    string restaurantId;
    OrderStatus fromStatus;
    OrderStatus toStatus;
    string reason;
    decimal total;
    DeliveryAddress deliveryAddress;
|};

public type KitchenOrderStatusUpdate record {|
    RestaurantStatus status;
|};

public type ProcessedEvent record {|
    string eventId;
    string eventType;
    string processedAt;
|};

// we use 'service cause service is a ballerina keyword so normal service wont work
public type HealthResponse record {|
    string status;
    string 'service;
|};

// lat just shot for lattitude btw and lng is longitude cause them names too long
public type RestaurantAddress record {|
    string street;
    string suburb;
    string city;
    decimal lat;
    decimal lng;
|};

// Day uses the enum above (Day) to use one of the valid days so we dont get
// smth like wedenesday or smth
public type OpeningHours record {|
    Day day;
    string open;
    string close;
|};

public type MenuItem record {|
    string itemId;
    string name;
    string description;
    decimal price;
    int stock;
    boolean available;
|};

public type OrderItemRequest record {|
    string itemId;
    int quantity;
|};

public type OrderValidationResult record {|
    boolean accepted;
    string reason;
    KitchenOrderItem[] items;
    decimal total;
    string currency;
|};

public type EventEnvelope record {|
    string eventId;
    string eventType;
    int version;
    string occurredAt;
    string 'source;
    string orderId;
    json data;
|};

public const REJECTED = "REJECTED";

public type RestaurantStatus PREPARING|READY|REJECTED;

public type PricedItem record {|
    string itemId;
    string name;
    int quantity;
    decimal unitPrice;
|};

public type OrderValidatedData record {|
    string restaurantId;
    string customerId;
    PricedItem[] items;
    decimal total;
    string currency;
    string reason;
    boolean accepted;
|};

public type RestaurantOrderUpdatedData record {|
    string restaurantId;
    RestaurantStatus status;
|};

// ok quick explainer cause this lwk confusing
// so why address isnt a list also is cause we only use one record of the address cause a resturant only has one location mos
// but we can have many opening hours and menu items so those are lists
// also the id is a string cause we use uuid for the id so it can be a string and not an int
public type Restaurant record {|
    string restaurantId;
    string name;
    string cuisine;
    RestaurantAddress address;
    OpeningHours[] openingHours;
    MenuItem[] menu;
    string createdAt;
|};

// This is the info the client sends when registering a restaurant.
public type RestaurantCreateRequest record {|
    string name;
    string cuisine;
    RestaurantAddress address;
    OpeningHours[] openingHours;
    MenuItem[] menu;
|};

// error handling cause bal doesnt have try except handling mxm
// so we use this to return an error if smth goes wrong
public type ErrorResponse record {|
    string 'error;
    string message;
|};

public type KitchenOrderItem record {|
    string itemId;
    string name;
    int quantity;
    decimal unitPrice;
|};

// same thing as Resturant record  with many kitchen order items can be in one item
// but one status per kitchen order so its not a list
public type KitchenOrder record {|
    string orderId;
    string restaurantId;
    KitchenOrderItem[] items;
    decimal total;
    KitchenOrderStatus status;
    string receivedAt;
    string updatedAt;
|};
