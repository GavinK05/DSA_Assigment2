import ballerinax/mongodb;

// these are the MongoDB handles we keep so we can reuse the same connection.
// mongodb:Database means this variable is a MongoDB database object, not our restaurant data.
mongodb:Client? mongoClient = ();
mongodb:Database? restaurantDatabase = ();
mongodb:Collection? restaurantsCollection = ();

// init() runs before the service starts and sets up the client, database, and collection.
// mongodb:Client, mongodb:Database, and mongodb:Collection are connector types we use later.
// the -> means we are calling a remote MongoDB function, kinda like calling a method on a Python client.
// check passes the connection error up if MongoDB is not running.
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

// MongoDB update syntax is kinda weird here because Update is its own record.
// set tells MongoDB which fields to replace, and the map after it tells it the new values.
public function updateHours(string restaurantId, OpeningHours[] openingHours) returns Restaurant|error {
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;
    mongodb:Update update = {set: {openingHours: openingHours}};
    // updateOne finds the restaurant by ID and writes the new hours to MongoDB.
    var updateResult = collectionValue->updateOne(
        {restaurantId: restaurantId},
        update,
        {}
    );

    if updateResult is error {
        return updateResult;
    }
    return findRestaurant(restaurantId);
}

public function addMenuItem(string restaurantId, MenuItem menuItem) returns Restaurant|error {
    Restaurant|error restaurantResult = findRestaurant(restaurantId);
    if restaurantResult is error {
        return restaurantResult;
    }
    Restaurant restaurant = restaurantResult;

    foreach MenuItem existingItem in restaurant.menu {
        if existingItem.itemId == menuItem.itemId {
            return error("DUPLICATE");
        }
    }

    restaurant.menu.push(menuItem);
    return saveMenu(restaurantId, restaurant.menu);
}

public function updateMenuItem(string restaurantId, string itemId, MenuItem menuItem) returns Restaurant|error {
    Restaurant|error restaurantResult = findRestaurant(restaurantId);
    if restaurantResult is error {
        return restaurantResult;
    }
    Restaurant restaurant = restaurantResult;
    MenuItem[] updatedMenu = [];
    boolean itemFound = false;

    foreach MenuItem existingItem in restaurant.menu {
        if existingItem.itemId == itemId {
            updatedMenu.push(menuItem);
            itemFound = true;
        } else {
            updatedMenu.push(existingItem);
        }
    }

    if !itemFound {
        return error("ITEM_NOT_FOUND");
    }
    return saveMenu(restaurantId, updatedMenu);
}

public function removeMenuItem(string restaurantId, string itemId) returns Restaurant|error {
    Restaurant|error restaurantResult = findRestaurant(restaurantId);
    if restaurantResult is error {
        return restaurantResult;
    }
    Restaurant restaurant = restaurantResult;
    MenuItem[] updatedMenu = [];
    boolean itemFound = false;

    foreach MenuItem existingItem in restaurant.menu {
        if existingItem.itemId == itemId {
            itemFound = true;
        } else {
            updatedMenu.push(existingItem);
        }
    }

    if !itemFound {
        return error("ITEM_NOT_FOUND");
    }
    return saveMenu(restaurantId, updatedMenu);
}

// we keep the repeated MongoDB menu update part in one function for all three menu operations.
// menu comes from the restaurant record, and the saved result goes back to MongoDB.
function saveMenu(string restaurantId, MenuItem[] menu) returns Restaurant|error {
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    // mongodb:Collection is the MongoDB collection object, not the menu list itself.
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;
    // set tells MongoDB which fields we want to replace.
    mongodb:Update update = {set: {menu: menu}};
    // updateOne finds the restaurant by ID and writes the new menu to MongoDB.
    var updateResult = collectionValue->updateOne(
        {restaurantId: restaurantId},
        update,
        {}
    );

    if updateResult is error {
        return updateResult;
    }
    return findRestaurant(restaurantId);
}

// quantity comes from the order, and the current stock comes from MongoDB.
// $gte means stock must be greater than or equal to quantity before we update it.
// $inc then subtracts the quantity, so MongoDB does the check and subtraction together.
public function reserveStock(string restaurantId, string itemId, int quantity) returns error? {
    if quantity <= 0 {
        return error("INVALID_QUANTITY");
    }
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;
    mongodb:Update update = {inc: {"menu.$.stock": -quantity}};
    var updateResult = collectionValue->updateOne(
        {restaurantId: restaurantId, "menu.itemId": itemId, "menu.stock": {"$gte": quantity}},
        update,
        {}
    );

    if updateResult is error {
        return updateResult;
    }
    // matchedCount tells us if MongoDB found an item with enough stock to reserve.
    if updateResult.matchedCount > 0 {
        return ();
    }

    Restaurant|error restaurantResult = findRestaurant(restaurantId);
    if restaurantResult is error {
        return restaurantResult;
    }
    foreach MenuItem menuItem in restaurantResult.menu {
        if menuItem.itemId == itemId {
            return error("OUT_OF_STOCK");
        }
    }
    return error("ITEM_NOT_FOUND");
}

public function releaseStock(string restaurantId, string itemId, int quantity) returns error? {
    if quantity <= 0 {
        return error("INVALID_QUANTITY");
    }
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    // this adds stock back when an earlier reservation needs to be cancelled.
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;
    mongodb:Update update = {inc: {"menu.$.stock": quantity}};
    var updateResult = collectionValue->updateOne(
        {restaurantId: restaurantId, "menu.itemId": itemId},
        update,
        {}
    );

    if updateResult is error {
        return updateResult;
    }
    if updateResult.matchedCount == 0 {
        return error("ITEM_NOT_FOUND");
    }
    return ();
}

