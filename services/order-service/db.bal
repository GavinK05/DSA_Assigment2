import ballerina/time;
import ballerinax/mongodb; 

## MongoDB client, connected to the "orders" database and "orders" collection. built from mongourl in config.toml. The client is used in the order-service to store and retrieve orders.
final mongodb:Client mongoClient = check new ({connection: mongoUrl});

#Returns the "orders" collection from the "order_db" database. The collection is used to store and retrieve orders.
function ordersCol() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase("order_db"); 
    return db->getCollection("orders");
}

# Saves a new order. 
function insertOrder(Order o) returns error? {
    mongodb:Collection col = check ordersCol();
    check col->insertOne(o);
}

#Find an order. 
function findOrder(string orderId) returns Order?|error {
    mongodb:Collection col = check ordersCol();
    return col->findOne({orderId: orderId});
}

#Update an order.
function updateStatus(string orderId, OrderStatus s, StatusEntry entry, string now) returns error? {
    mongodb:Collection col = check ordersCol();
    _ = check col->updateOne({orderId:orderId}, {set: {status: s, updatedAt: now}, "$push": {statusHistory: entry.toJson()}});
}

# Returns the processed_events collection for duplicate checking. 
function eventsCol() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase("order_db");
    return db->getCollection("processed_events");
}

# Finds all orders matching a filter, e.g. {customerId: "CUS-1"}.
function findOrders(map<json> filter) returns Order[]|error {
    mongodb:Collection col = check ordersCol();
    stream<Order, error?> results = check col->find(filter);
    return from Order o in results select o;
}

# True if this eventId has already been handled.
function isEventProcessed(string eventId) returns boolean|error {
    mongodb:Collection col = check eventsCol(); 
    int count = check col->countDocuments({eventId: eventId});
    return count > 0;
}

# Sets extra fields on an order, e.g. total or driverId.
function setFields(string orderId, map<json> fields) returns error? {
    mongodb:Collection col = check ordersCol();
    _ = check col->updateOne({orderId: orderId}, {set: fields});
}
# Marks event as handled, skipping it in future duplicate checks. This is called after the event has been processed successfully.
function markEventProcessed(string eventId) returns error? {
    mongodb:Collection col = check eventsCol();
    _ = check col->insertOne({eventId: eventId, processedAt: time:utcToString(time:utcNow())});
}
