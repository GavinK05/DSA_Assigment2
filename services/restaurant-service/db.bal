import ballerinax/mongodb;

// these are the MongoDB handles we keep so we can reuse the same connection.
// mongodb:Database means this variable is a MongoDB database object, not our restaurant data.
mongodb:Client? mongoClient = ();
mongodb:Database? restaurantDatabase = ();
mongodb:Collection? restaurantsCollection = ();
mongodb:Collection? kitchenOrdersCollection = ();
mongodb:Collection? processedEventsCollection = ();

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
    kitchenOrdersCollection = check databaseValue->getCollection("kitchen_orders");
    if kitchenOrdersCollection is () {
        return error("Kitchen orders collection was not initialized");
    }
    processedEventsCollection = check databaseValue->getCollection("processed_events");
    if processedEventsCollection is () {
        return error("Processed events collection was not initialized");
    }

    mongodb:Collection kitchenCollectionValue = <mongodb:Collection>kitchenOrdersCollection;
    mongodb:Collection eventsCollectionValue = <mongodb:Collection>processedEventsCollection;
    mongodb:Collection restaurantCollectionValue = <mongodb:Collection>restaurantsCollection;
    check restaurantCollectionValue->createIndex(
        {name: 1, "address.city": 1},
        {unique: true, name: "restaurant_name_city"}
    );
    check kitchenCollectionValue->createIndex({orderId: 1}, {unique: true, name: "kitchen_order_id"});
    check eventsCollectionValue->createIndex({eventId: 1}, {unique: true, name: "processed_event_id"});
}

# Inserts a new restaurant document into MongoDB.
# + restaurant - Complete restaurant record to insert.
# + return - The inserted restaurant or an error.
public function insertRestaurant(Restaurant restaurant) returns Restaurant|error {
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;
    Restaurant|error? existing = collectionValue->findOne(
        {name: restaurant.name, "address.city": restaurant.address.city},
        targetType = Restaurant
    );
    if existing is Restaurant {
        return error("DUPLICATE");
    }
    if existing is error {
        return existing;
    }
    error? insertResult = collectionValue->insertOne(restaurant);
    if insertResult is error {
        Restaurant|error? duplicate = collectionValue->findOne(
            {name: restaurant.name, "address.city": restaurant.address.city},
            targetType = Restaurant
        );
        if duplicate is Restaurant {
            return error("DUPLICATE");
        }
        return insertResult;
    }
    return restaurant;
}

// this function retrieves a restaurant by its ID from the MongoDB collection
# Finds a restaurant by its restaurant ID.
# + restaurantId - ID to search for.
# + return - The restaurant or an error when it is missing or MongoDB fails.
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
# Retrieves all restaurants from MongoDB.
# + return - All stored restaurants or an error.
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
# Replaces the opening-hours schedule for one restaurant.
# + restaurantId - ID of the restaurant to update.
# + openingHours - Validated weekly schedule.
# + return - The updated restaurant or an error.
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

# Adds a menu item after checking for a duplicate item ID.
# + restaurantId - Restaurant that owns the menu.
# + menuItem - Item to append to the menu.
# + return - The updated restaurant or an error.
public function addMenuItem(string restaurantId, MenuItem menuItem) returns Restaurant|error {
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;
    mongodb:Update update = {"push": {menu: menuItem}};
    var updateResult = collectionValue->updateOne(
        {restaurantId: restaurantId, "menu.itemId": {"$ne": menuItem.itemId}},
        update,
        {}
    );
    if updateResult is error {
        return updateResult;
    }
    if updateResult.matchedCount == 0 {
        Restaurant|error existingRestaurant = findRestaurant(restaurantId);
        if existingRestaurant is error {
            return existingRestaurant;
        }
        foreach MenuItem existingItem in existingRestaurant.menu {
            if existingItem.itemId == menuItem.itemId {
                return error("DUPLICATE");
            }
        }
        return error("NOT_FOUND");
    }
    return findRestaurant(restaurantId);
}

# Updates one menu item using MongoDB's positional array operator.
# + restaurantId - Restaurant that owns the item.
# + itemId - ID of the menu item to replace.
# + menuItem - Updated menu item data.
# + return - The updated restaurant or an error.
public function updateMenuItem(string restaurantId, string itemId, MenuItem menuItem) returns Restaurant|error {
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;
    mongodb:Update update = {set: {"menu.$": menuItem}};
    var updateResult = collectionValue->updateOne(
        {restaurantId: restaurantId, "menu.itemId": itemId},
        update,
        {}
    );
    if updateResult is error {
        return updateResult;
    }
    if updateResult.matchedCount == 0 {
        Restaurant|error existingRestaurant = findRestaurant(restaurantId);
        if existingRestaurant is error {
            return existingRestaurant;
        }
        return error("ITEM_NOT_FOUND");
    }
    return findRestaurant(restaurantId);
}

# Removes one menu item using MongoDB's array pull operator.
# + restaurantId - Restaurant that owns the item.
# + itemId - ID of the item to remove.
# + return - The updated restaurant or an error.
public function removeMenuItem(string restaurantId, string itemId) returns Restaurant|error {
    if restaurantsCollection is () {
        return error("Restaurant collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>restaurantsCollection;
    mongodb:Update update = {"pull": {menu: {itemId: itemId}}};
    var updateResult = collectionValue->updateOne(
        {restaurantId: restaurantId, "menu.itemId": itemId},
        update,
        {}
    );

    if updateResult is error {
        return updateResult;
    }
    if updateResult.matchedCount == 0 {
        Restaurant|error existingRestaurant = findRestaurant(restaurantId);
        if existingRestaurant is error {
            return existingRestaurant;
        }
        return error("ITEM_NOT_FOUND");
    }
    return findRestaurant(restaurantId);
}

// quantity comes from the order, and the current stock comes from MongoDB.
// $gte means stock must be greater than or equal to quantity before we update it.
// $inc then subtracts the quantity, so MongoDB does the check and subtraction together.
# Atomically checks availability and reserves menu stock.
# + restaurantId - Restaurant that owns the stock.
# + itemId - Menu item to reserve.
# + quantity - Positive number of units to reserve.
# + return - An error if stock cannot be reserved or MongoDB fails.
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
        {
            restaurantId: restaurantId,
            menu: {"$elemMatch": {itemId: itemId, stock: {"$gte": quantity}, available: true}}
        },
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

# Adds a previously reserved quantity back to menu stock.
# + restaurantId - Restaurant that owns the stock.
# + itemId - Menu item to restore.
# + quantity - Positive number of units to release.
# + return - An error if stock cannot be released or MongoDB fails.
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
        {restaurantId: restaurantId, menu: {"$elemMatch": {itemId: itemId}}},
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

# Checks whether this event ID has already been recorded as handled.
# + eventId - Kafka event ID to check.
# + return - True if already processed, otherwise false; MongoDB failures are returned as errors.
public function isEventProcessed(string eventId) returns boolean|error {
    if processedEventsCollection is () {
        return error("Processed events collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>processedEventsCollection;
    ProcessedEvent|error? result = collectionValue->findOne(
        {eventId: eventId},
        targetType = ProcessedEvent
    );
    if result is ProcessedEvent {
        return true;
    }
    if result is error {
        return result;
    }
    return false;
}

# Records a handled event so Kafka redelivery does not repeat its effects.
# + eventId - Kafka event ID to store.
# + eventType - Event type from the shared envelope.
# + processedAt - UTC timestamp when processing completed.
# + return - An error if the event could not be recorded.
public function markEventProcessed(string eventId, string eventType, string processedAt) returns error? {
    if processedEventsCollection is () {
        return error("Processed events collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>processedEventsCollection;
    ProcessedEvent processedEvent = {
        eventId: eventId,
        eventType: eventType,
        processedAt: processedAt
    };
    error? insertResult = collectionValue->insertOne(processedEvent);
    if insertResult is error {
        boolean alreadyProcessed = check isEventProcessed(eventId);
        if alreadyProcessed {
            return ();
        }
        return insertResult;
    }
}

# Inserts or replaces the saved kitchen view of an order by its order ID.
# + kitchenOrder - Kitchen order state to persist.
# + return - An error if MongoDB cannot save the order.
public function upsertKitchenOrder(KitchenOrder kitchenOrder) returns error? {
    if kitchenOrdersCollection is () {
        return error("Kitchen orders collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>kitchenOrdersCollection;
    mongodb:Update update = {set: kitchenOrder};
    var updateResult = collectionValue->updateOne(
        {orderId: kitchenOrder.orderId},
        update,
        {upsert: true}
    );
    if updateResult is error {
        return updateResult;
    }
}

# Retrieves one kitchen order scoped to its restaurant.
# + restaurantId - Restaurant that owns the kitchen order.
# + orderId - Order to retrieve.
# + return - The kitchen order or an error.
public function findKitchenOrder(string restaurantId, string orderId) returns KitchenOrder|error {
    if kitchenOrdersCollection is () {
        return error("Kitchen orders collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>kitchenOrdersCollection;
    KitchenOrder|error? result = collectionValue->findOne(
        {restaurantId: restaurantId, orderId: orderId},
        targetType = KitchenOrder
    );
    if result is KitchenOrder {
        return result;
    }
    if result is error {
        return result;
    }
    return error("ORDER_NOT_FOUND");
}

# Lists kitchen orders for one restaurant, optionally filtered by status.
# + restaurantId - Restaurant whose queue is requested.
# + status - Optional kitchen status filter.
# + return - Matching kitchen orders or an error.
public function findKitchenOrders(string restaurantId, string? status = ()) returns KitchenOrder[]|error {
    if kitchenOrdersCollection is () {
        return error("Kitchen orders collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>kitchenOrdersCollection;
    map<json> filter = {restaurantId: restaurantId};
    if status is string {
        filter["status"] = status;
    }
    stream<KitchenOrder, error?> orderStream = check collectionValue->find(
        filter,
        targetType = KitchenOrder
    );
    KitchenOrder[] orders = [];
    while true {
        var nextValue = orderStream.next();
        if nextValue is error {
            return nextValue;
        }
        if nextValue is () {
            break;
        }
        orders.push(nextValue.value);
    }
    check orderStream.close();
    return orders;
}

# Updates an order only while its saved status still matches the expected status.
# + restaurantId - Restaurant that owns the order.
# + orderId - Order to update.
# + expectedStatus - Current status required for the update to apply.
# + nextStatus - Status to persist.
# + updatedAt - UTC timestamp of the change.
# + return - Updated order, conflict/missing error, or database error.
public function updateKitchenOrderStatus(
        string restaurantId,
        string orderId,
        KitchenOrderStatus expectedStatus,
        KitchenOrderStatus nextStatus,
        string updatedAt
) returns KitchenOrder|error {
    if kitchenOrdersCollection is () {
        return error("Kitchen orders collection is not initialized");
    }
    mongodb:Collection collectionValue = <mongodb:Collection>kitchenOrdersCollection;
    mongodb:Update update = {set: {status: nextStatus.toString(), updatedAt: updatedAt}};
    var updateResult = collectionValue->updateOne(
        {
            restaurantId: restaurantId,
            orderId: orderId,
            status: expectedStatus.toString()
        },
        update,
        {}
    );
    if updateResult is error {
        return updateResult;
    }
    if updateResult.matchedCount == 0 {
        KitchenOrder|error existingOrder = findKitchenOrder(restaurantId, orderId);
        if existingOrder is error {
            return existingOrder;
        }
        return error("CONFLICT");
    }
    return findKitchenOrder(restaurantId, orderId);
}
