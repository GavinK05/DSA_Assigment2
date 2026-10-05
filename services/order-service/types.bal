# One item in an order. name and unitPrice arrive later, when the restaurant validates.
public type OrderLine record {|
    string itemId;
    int quantity;
    string name?;
    decimal unitPrice?;
|};

# One entry in an order's status timeline.
public type StatusEntry record {|
    OrderStatus status;
    string at; // ISO timestamp, e.g. "2026-10-05T12:00:00Z"
    string reason;
|};

# An order as stored in MongoDB.
public type Order record {|
    string orderId;
    string customerId;
    string restaurantId;
    OrderLine[] items;
    Address deliveryAddress;
    decimal total;
    string currency;
    OrderStatus status;
    string driverId?;
    StatusEntry[] statusHistory;
    string createdAt;
    string updatedAt;
|};

# The JSON body for POST /orders.
public type NewOrderRequest record {|
    string customerId;
    string restaurantId;
    OrderItem[] items; // what the customer sends: itemId + quantity only
    Address deliveryAddress;
|};

# Error body, README section 6: {"error": "...", "message": "..."}
public type ErrorBody record {|
    string 'error;
    string message;
|};

# Raised when a status change breaks the state machine (becomes HTTP 409).
public type InvalidTransitionError distinct error;
