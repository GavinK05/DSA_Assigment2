import ballerina/time;
import ballerinax/mongodb;

mongodb:Client? mongoClient = ();
mongodb:Collection? restaurantStatsCollection = ();
mongodb:Collection? driverStatsCollection = ();
mongodb:Collection? orderStatsCollection = ();
mongodb:Collection? paymentStatsCollection = ();
mongodb:Collection? processedEventsCollection = ();

function init() returns error? {
    mongodb:Client mongo = check new ({connection: mongoUrl});
    mongoClient = mongo;
    mongodb:Database database = check mongo->getDatabase("admin_db");
    mongodb:Collection restaurants = check database->getCollection("restaurant_stats");
    mongodb:Collection drivers = check database->getCollection("driver_stats");
    mongodb:Collection orders = check database->getCollection("order_stats");
    mongodb:Collection payments = check database->getCollection("payment_stats");
    mongodb:Collection events = check database->getCollection("processed_events");
    restaurantStatsCollection = restaurants;
    driverStatsCollection = drivers;
    orderStatsCollection = orders;
    paymentStatsCollection = payments;
    processedEventsCollection = events;

    check restaurants->createIndex({restaurantId: 1}, {unique: true, name: "stat_restaurant_id"});
    check drivers->createIndex({driverId: 1}, {unique: true, name: "stat_driver_id"});
    check orders->createIndex({status: 1}, {unique: true, name: "stat_order_status"});
    check payments->createIndex({status: 1}, {unique: true, name: "stat_payment_status"});
    check events->createIndex({eventId: 1}, {unique: true, name: "processed_event_id"});
}

function coll(mongodb:Collection? c, string name) returns mongodb:Collection|error {
    return c is mongodb:Collection ? c : error(name + " collection is not initialized");
}

// Upsert that $incs the given fields and seeds every other field with its default,
// so a brand-new stat document always has the full shape.
function incrementStat(mongodb:Collection c, map<json> filter, map<json> increments, map<json> defaults) returns error? {
    map<json> seed = {};
    foreach var [key, value] in defaults.entries() {
        if !increments.hasKey(key) {
            seed[key] = value;
        }
    }
    _ = check c->updateOne(filter, {inc: increments, setOnInsert: seed}, {upsert: true});
}

# Adds to one restaurant's counters, creating the stat row if needed.
# + restaurantId - Restaurant the event is about.
# + orders - Amount to add to totalOrders.
# + delivered - Amount to add to delivered.
# + cancelled - Amount to add to cancelled.
# + revenue - Amount to add to revenue.
# + return - An error if MongoDB fails.
public function incrementRestaurantStat(string restaurantId, int orders = 0, int delivered = 0, int cancelled = 0,
        decimal revenue = 0d) returns error? {
    mongodb:Collection c = check coll(restaurantStatsCollection, "restaurant_stats");
    map<json> increments = {};
    if orders != 0 {
        increments["totalOrders"] = orders;
    }
    if delivered != 0 {
        increments["delivered"] = delivered;
    }
    if cancelled != 0 {
        increments["cancelled"] = cancelled;
    }
    if revenue != 0d {
        increments["revenue"] = revenue;
    }
    check incrementStat(c, {restaurantId: restaurantId}, increments,
        {totalOrders: 0, delivered: 0, cancelled: 0, revenue: 0d});
}

# Adds to one driver's counters, creating the stat row if needed.
# + driverId - Driver the event is about.
# + completed - Amount to add to completed.
# + minutes - Amount to add to totalMinutes.
# + return - An error if MongoDB fails.
public function incrementDriverStat(string driverId, int completed = 0, int minutes = 0) returns error? {
    mongodb:Collection c = check coll(driverStatsCollection, "driver_stats");
    map<json> increments = {};
    if completed != 0 {
        increments["completed"] = completed;
    }
    if minutes != 0 {
        increments["totalMinutes"] = minutes;
    }
    check incrementStat(c, {driverId: driverId}, increments, {completed: 0, totalMinutes: 0});
}

# Adds to the count of orders in one status (use a negative amount to move an order out of it).
# + status - Order status.
# + amount - Amount to add.
# + return - An error if MongoDB fails.
public function incrementOrderStat(string status, int amount) returns error? {
    mongodb:Collection c = check coll(orderStatsCollection, "order_stats");
    check incrementStat(c, {status: status}, {count: amount}, {count: 0});
}

# Adds one payment outcome to the SUCCESS or FAILED totals.
# + status - SUCCESS or FAILED.
# + amount - Payment amount.
# + return - An error if MongoDB fails.
public function incrementPaymentStat(string status, decimal amount) returns error? {
    mongodb:Collection c = check coll(paymentStatsCollection, "payment_stats");
    check incrementStat(c, {status: status}, {count: 1, amount: amount}, {count: 0, amount: 0d});
}

# Lists stats for every restaurant.
# + return - The stats, or a MongoDB error.
public function findRestaurantStats() returns RestaurantStat[]|error {
    mongodb:Collection c = check coll(restaurantStatsCollection, "restaurant_stats");
    stream<RestaurantStat, error?> rows = check c->find({}, targetType = RestaurantStat);
    RestaurantStat[] result = [];
    check from RestaurantStat row in rows
        do {
            result.push(row);
        };
    return result;
}

# Finds stats for one restaurant.
# + restaurantId - Restaurant to look up.
# + return - The stats, or NOT_FOUND / a MongoDB error.
public function findRestaurantStat(string restaurantId) returns RestaurantStat|error {
    mongodb:Collection c = check coll(restaurantStatsCollection, "restaurant_stats");
    RestaurantStat|error? found = c->findOne({restaurantId: restaurantId}, targetType = RestaurantStat);
    if found is RestaurantStat|error {
        return found;
    }
    return error("NOT_FOUND");
}

# Lists stats for every driver.
# + return - The stats, or a MongoDB error.
public function findDriverStats() returns DriverStat[]|error {
    mongodb:Collection c = check coll(driverStatsCollection, "driver_stats");
    stream<DriverStat, error?> rows = check c->find({}, targetType = DriverStat);
    DriverStat[] result = [];
    check from DriverStat row in rows
        do {
            result.push(row);
        };
    return result;
}

# Lists the per-status order counts.
# + return - The counts, or a MongoDB error.
public function findOrderStats() returns OrderStat[]|error {
    mongodb:Collection c = check coll(orderStatsCollection, "order_stats");
    stream<OrderStat, error?> rows = check c->find({}, targetType = OrderStat);
    OrderStat[] result = [];
    check from OrderStat row in rows
        do {
            result.push(row);
        };
    return result;
}

# Lists the payment success/failure totals.
# + return - The totals, or a MongoDB error.
public function findPaymentStats() returns PaymentStat[]|error {
    mongodb:Collection c = check coll(paymentStatsCollection, "payment_stats");
    stream<PaymentStat, error?> rows = check c->find({}, targetType = PaymentStat);
    PaymentStat[] result = [];
    check from PaymentStat row in rows
        do {
            result.push(row);
        };
    return result;
}

# Checks whether an event was already handled.
# + eventId - Event to check.
# + return - True if already processed.
public function isEventProcessed(string eventId) returns boolean|error {
    mongodb:Collection e = check coll(processedEventsCollection, "processed_events");
    ProcessedEvent|error? found = e->findOne({eventId: eventId}, targetType = ProcessedEvent);
    if found is error {
        return found;
    }
    return found is ProcessedEvent;
}

# Records an event as handled; a duplicate insert is treated as success.
# + eventId - Event ID.
# + eventType - Event type.
# + return - An error if MongoDB fails.
public function markEventProcessed(string eventId, string eventType) returns error? {
    mongodb:Collection e = check coll(processedEventsCollection, "processed_events");
    ProcessedEvent row = {eventId: eventId, eventType: eventType, processedAt: time:utcToString(time:utcNow())};
    error? result = e->insertOne(row);
    if result is error {
        boolean done = check isEventProcessed(eventId);
        if !done {
            return result;
        }
    }
}
