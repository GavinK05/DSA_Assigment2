import ballerinax/mongodb;

// These handles are created once during module initialization.
// idk i was told we need em (this my first time using mongodb lol)
mongodb:Client? mongoClient = ();
mongodb:Database? restaurantDatabase = ();
mongodb:Collection? restaurantsCollection = ();

// init() runs before the service starts and is used to set up the mongoDB client, database, and collection
// in short just sets up the connection to the database and collection so we can use it later
// ngl to you the value assignment syntax in bal sucks  so instead of
// mongoClient = new ({connection: mongoUrl}); we have to do this weird check with the :
function init() returns error? {
    mongoClient = check new ({connection: mongoUrl});
    if mongoClient is () {
        return error("MongoDB client was not initialized");
    }
    mongodb:Client mongoClientValue = <mongodb:Client>mongoClient;
    restaurantDatabase = check mongoClientValue->getDatabase("restaurant_db");
    if restaurantDatabase is () {
        return error("Restaurant database was not initialized");
    }
    mongodb:Database databaseValue = <mongodb:Database>restaurantDatabase;
    restaurantsCollection = check databaseValue->getCollection("restaurants");
    if restaurantsCollection is () {
        return error("Restaurant collection was not initialized");
    }
}

public function insertRestaurant(Restaurant restaurant) returns Restaurant|error {
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;
    check collectionValue->insertOne(restaurant);
    return restaurant;
}

// this function retrieves a restaurant by its ID from the MongoDB collection
public function findRestaurant(string restaurantId) returns Restaurant|error {
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;

    Restaurant|error? restaurant = collectionValue->findOne(
        {restaurantId: restaurantId},
        targetType = Restaurant
    );

    if restaurant is Restaurant {
        return restaurant;
    }
    if restaurant is error {
        return restaurant;
    }
    return error("NOT_FOUND");
}

// this function retrieves all restaurants from the MongoDB collection
public function findRestaurants() returns Restaurant[]|error {
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;

    stream<Restaurant, error?> restaurantStream = check collectionValue->find(
        {},
        targetType = Restaurant
    );
    Restaurant[] restaurants = [];

    while true {
        var nextValue = restaurantStream.next();
        if nextValue is error {
            return nextValue;
        }
        if nextValue is () {
            break;
        }
        Restaurant restaurant = nextValue.value;
        restaurants.push(restaurant);
    }

    check restaurantStream.close();
    return restaurants;
}

