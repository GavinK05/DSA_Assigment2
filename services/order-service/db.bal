import ballerinax/mongodb; 

## MongoDB client, connected to the "orders" database and "orders" collection. built from mongourl in config.toml. The client is used in the order-service to store and retrieve orders.
final mongodb:Client mongoClient = check new ({connection: mongoUrl});

#Returns the "orders" collection from the "order_db" database. The collection is used to store and retrieve orders.
function ordersCol() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase("order_db"); 
    return db->getCollection("orders");
}