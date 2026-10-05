import ballerina/time;
import ballerinax/mongodb;

mongodb:Client? mongoClient = ();
mongodb:Collection? customersCollection = ();
mongodb:Collection? orderHistoryCollection = ();
mongodb:Collection? processedEventsCollection = ();

function init() returns error? {
    mongodb:Client mongo = check new ({connection: mongoUrl});
    mongoClient = mongo;
    mongodb:Database database = check mongo->getDatabase("customer_db");
    mongodb:Collection customers = check database->getCollection("customers");
    mongodb:Collection history = check database->getCollection("order_history");
    mongodb:Collection events = check database->getCollection("processed_events");
    customersCollection = customers;
    orderHistoryCollection = history;
    processedEventsCollection = events;

    check customers->createIndex({customerId: 1}, {unique: true, name: "customer_id"});
    check customers->createIndex({email: 1}, {unique: true, name: "customer_email"});
    check history->createIndex({orderId: 1}, {unique: true, name: "history_order_id"});
    check history->createIndex({customerId: 1}, {name: "history_customer_id"});
    check events->createIndex({eventId: 1}, {unique: true, name: "processed_event_id"});
}

function customers() returns mongodb:Collection|error {
    mongodb:Collection? c = customersCollection;
    return c is mongodb:Collection ? c : error("customers collection is not initialized");
}

function history() returns mongodb:Collection|error {
    mongodb:Collection? c = orderHistoryCollection;
    return c is mongodb:Collection ? c : error("order_history collection is not initialized");
}

function events() returns mongodb:Collection|error {
    mongodb:Collection? c = processedEventsCollection;
    return c is mongodb:Collection ? c : error("processed_events collection is not initialized");
}

# Inserts a new customer; the unique email index guards against races.
# + customer - Complete customer record.
# + return - The inserted customer, or DUPLICATE / a MongoDB error.
public function insertCustomer(Customer customer) returns Customer|error {
    mongodb:Collection c = check customers();
    error? result = c->insertOne(customer);
    if result is error {
        Customer|error existing = findCustomerByEmail(customer.email);
        if existing is Customer {
            return error("DUPLICATE");
        }
        return result;
    }
    return customer;
}

# Finds a customer by ID.
# + customerId - ID to look up.
# + return - The customer, or NOT_FOUND / a MongoDB error.
public function findCustomer(string customerId) returns Customer|error {
    mongodb:Collection c = check customers();
    Customer|error? found = c->findOne({customerId: customerId}, targetType = Customer);
    if found is Customer|error {
        return found;
    }
    return error("NOT_FOUND");
}

# Finds a customer by (lower-cased) email.
# + email - Email to look up.
# + return - The customer, or NOT_FOUND / a MongoDB error.
public function findCustomerByEmail(string email) returns Customer|error {
    mongodb:Collection c = check customers();
    Customer|error? found = c->findOne({email: email}, targetType = Customer);
    if found is Customer|error {
        return found;
    }
    return error("NOT_FOUND");
}

# Updates the name and/or phone of a customer.
# + customerId - Customer to update.
# + name - New name, or () to leave unchanged.
# + phone - New phone, or () to leave unchanged.
# + return - The updated customer, or NOT_FOUND / a MongoDB error.
public function updateCustomer(string customerId, string? name, string? phone) returns Customer|error {
    mongodb:Collection c = check customers();
    map<json> changes = {};
    if name is string {
        changes["name"] = name;
    }
    if phone is string {
        changes["phone"] = phone;
    }
    mongodb:UpdateResult result = check c->updateOne({customerId: customerId}, {set: changes});
    if result.matchedCount == 0 {
        return error("NOT_FOUND");
    }
    return findCustomer(customerId);
}

# Appends an address to a customer.
# + customerId - Customer that owns the address.
# + address - Address to add.
# + return - NOT_FOUND if the customer does not exist, or a MongoDB error.
public function addAddress(string customerId, Address address) returns error? {
    mongodb:Collection c = check customers();
    mongodb:UpdateResult result = check c->updateOne({customerId: customerId}, {"push": {addresses: address}});
    if result.matchedCount == 0 {
        return error("NOT_FOUND");
    }
}

# Removes one address from a customer.
# + customerId - Customer that owns the address.
# + addressId - Address to remove.
# + return - NOT_FOUND (customer) / ADDRESS_NOT_FOUND, or a MongoDB error.
public function removeAddress(string customerId, string addressId) returns error? {
    mongodb:Collection c = check customers();
    mongodb:UpdateResult result = check c->updateOne(
        {customerId: customerId, "addresses.addressId": addressId},
        {"pull": {addresses: {addressId: addressId}}}
    );
    if result.matchedCount == 0 {
        _ = check findCustomer(customerId);
        return error("ADDRESS_NOT_FOUND");
    }
}

# Creates or updates the order-history copy of an order.
# + entry - Fields learned from an event; createdAt only applies on first insert.
# + forceStatus - If true the status/total overwrite an existing row (status-changed); if false they only seed a new row (orders.created).
# + return - An error if MongoDB fails.
public function upsertOrderHistory(OrderHistoryEntry entry, boolean forceStatus) returns error? {
    mongodb:Collection h = check history();
    map<json> onInsert = {
        orderId: entry.orderId,
        customerId: entry.customerId,
        restaurantId: entry.restaurantId,
        createdAt: entry.createdAt
    };
    map<json> set = {updatedAt: entry.updatedAt};
    if forceStatus {
        set["status"] = entry.status;
        set["total"] = entry.total;
    } else {
        onInsert["status"] = entry.status;
        onInsert["total"] = entry.total;
    }
    _ = check h->updateOne({orderId: entry.orderId}, {set: set, setOnInsert: onInsert}, {upsert: true});
}

# Lists a customer's orders, newest first.
# + customerId - Customer whose orders to list.
# + return - The orders, or a MongoDB error.
public function findOrderHistory(string customerId) returns OrderHistoryEntry[]|error {
    mongodb:Collection h = check history();
    stream<OrderHistoryEntry, error?> rows = check h->find(
        {customerId: customerId},
        {sort: {createdAt: -1}},
        targetType = OrderHistoryEntry
    );
    OrderHistoryEntry[] orders = [];
    check from OrderHistoryEntry row in rows
        do {
            orders.push(row);
        };
    return orders;
}

# Checks whether an event was already handled.
# + eventId - Event to check.
# + return - True if already processed.
public function isEventProcessed(string eventId) returns boolean|error {
    mongodb:Collection e = check events();
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
    mongodb:Collection e = check events();
    ProcessedEvent row = {eventId: eventId, eventType: eventType, processedAt: time:utcToString(time:utcNow())};
    error? result = e->insertOne(row);
    if result is error {
        boolean done = check isEventProcessed(eventId);
        if !done {
            return result;
        }
    }
}
