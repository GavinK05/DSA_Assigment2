import ballerina/time;
import ballerina/uuid;

# True if the state machine allows moving from current to next (README section 4.3).
public function isValidTransition(OrderStatus current, OrderStatus next) returns boolean {
    match current {
        CREATED => {
            return next == CONFIRMED || next == CANCELLED;
        }
        CONFIRMED => {
            return next == PREPARING || next == CANCELLED;
        }
        PREPARING => {
            return next == READY;
        }
        READY => {
            return next == OUT_FOR_DELIVERY;
        }
        OUT_FOR_DELIVERY => {
            return next == DELIVERED;
        }
    }
    return false; // DELIVERED and CANCELLED are final
}

# Validates, saves and records a status change. Every status change in the service goes through here.
public function changeStatus(string orderId, OrderStatus next, string reason) returns Order|error {
    // load the order from the database
    Order? found = check findOrder(orderId);
    if found is () {
        return error("NOT_FOUND: did not find order with id " + orderId);
    }
    Order o = found;
    OrderStatus previous = o.status; // store the previous status for the status-changed event

    // ask the state machine whether this move is allowed
    if !isValidTransition(previous, next) {
        return error InvalidTransitionError("Cannot move order from " + previous + " to " + next);
    }

    // build the history entry
    string now = time:utcToString(time:utcNow());
    StatusEntry entry = {status: next, at: now, reason: reason};

    // save the new status and history entry to MongoDB
    check updateStatus(orderId, next, entry, now);

    // keep our local copy in sync with the database
    o.status = next;
    o.updatedAt = now;
    o.statusHistory.push(entry);

    // TODO Stage 7: publishStatusChanged(o, previous, reason);
    return o;
}


# Creates a new order in CREATED status and saves it to MongoDB.
public function createOrder(NewOrderRequest req) returns Order|error {
    if req.items.length() == 0 {
        return error("Order must have at least one item.");
    }

    string now = time:utcToString(time:utcNow());
    string orderId = "ORD-" + uuid:createType4AsString();

    OrderLine[] lines = from OrderItem i in req.items select {itemId: i.itemId, quantity: i.quantity};

    Order o = {
        orderId: orderId,
        customerId: req.customerId,
        restaurantId: req.restaurantId,
        items: lines,
        deliveryAddress: req.deliveryAddress,
        total: 0d,
        currency: "NAD",
        status: CREATED,
        statusHistory: [{status: CREATED, at: now, reason: "Order created"}],
        createdAt: now,
        updatedAt: now
    };

    check insertOrder(o);
    // TODO Stage 7: publishOrderCreated(o);
    return o;
}
