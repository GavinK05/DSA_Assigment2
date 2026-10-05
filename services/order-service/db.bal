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
    _ = check col->updateOne({orderId:orderId}, {set: {status: s, updatedAt: now}});
}