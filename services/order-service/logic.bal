import ballerina/time;

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
