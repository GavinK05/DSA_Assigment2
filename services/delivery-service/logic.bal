import ballerina/log;
import ballerina/time;
import ballerina/uuid;

# Current time as ISO-8601 UTC.
function nowUtc() returns string => time:utcToString(time:utcNow());

# Whole minutes between two ISO-8601 timestamps (rounded).
function minutesBetween(string fromIso, string toIso) returns int|error {
    time:Utc fromTime = check time:utcFromString(fromIso);
    time:Utc toTime = check time:utcFromString(toIso);
    time:Seconds diff = time:utcDiffSeconds(toTime, fromTime);
    return <int>(diff / 60.0d);
}

// ---------- Drivers ----------

# Validates and saves a new driver, then gives them a waiting order if there is one.
function registerDriver(NewDriver input) returns Driver|error {
    string name = input.name.trim();
    string phone = input.phone.trim();
    string vehicle = input.vehicle.trim();
    if name == "" || phone == "" || vehicle == "" {
        return error ValidationError("name, phone and vehicle are required");
    }
    Driver driver = {
        driverId: "DRV-" + uuid:createType4AsString(),
        name,
        phone,
        vehicle,
        status: AVAILABLE,
        location: (),
        updatedAt: nowUtc()
    };
    check insertDriver(driver);
    log:printInfo("driver registered", driverId = driver.driverId);
    check assignPendingIfAny();
    Driver? latest = check findDriver(driver.driverId);
    return latest ?: driver;
}

# Driver sets themselves AVAILABLE or OFFLINE. BUSY is only set by the system.
function changeDriverStatus(string driverId, DriverStatus newStatus) returns Driver|error {
    if newStatus == BUSY {
        return error ValidationError("BUSY is set automatically when a delivery is assigned");
    }
    Driver? driver = check findDriver(driverId);
    if driver is () {
        return error NotFoundError(string `Driver ${driverId} does not exist`);
    }
    if driver.status == BUSY {
        return error ConflictError(string `Driver ${driverId} is on a delivery`);
    }
    boolean updated = check updateDriverStatus(driverId, newStatus, driver.status);
    if !updated {
        return error ConflictError(string `Driver ${driverId} changed status at the same time, try again`);
    }
    if newStatus == AVAILABLE {
        check assignPendingIfAny();
    }
    Driver? latest = check findDriver(driverId);
    return latest ?: driver;
}

# Saves a driver's location after checking the coordinates.
function updateLocation(string driverId, LocationUpdate input) returns Driver|error {
    if input.lat < -90.0 || input.lat > 90.0 || input.lng < -180.0 || input.lng > 180.0 {
        return error ValidationError("lat must be -90..90 and lng must be -180..180");
    }
    boolean found = check updateDriverLocation(driverId, {lat: input.lat, lng: input.lng});
    Driver? driver = check findDriver(driverId);
    if !found || driver is () {
        return error NotFoundError(string `Driver ${driverId} does not exist`);
    }
    return driver;
}

# Atomically takes the longest-waiting AVAILABLE driver and marks them BUSY.
# Retries if another request grabbed the same driver first.
function claimDriver() returns Driver|error? {
    foreach int attempt in 0 ..< 5 {
        Driver? candidate = check findAvailableDriver();
        if candidate is () {
            return ();
        }
        boolean claimed = check updateDriverStatus(candidate.driverId, BUSY, AVAILABLE);
        if claimed {
            candidate.status = BUSY;
            return candidate;
        }
    }
    return ();
}

// ---------- Assignment ----------

# Called when an order becomes READY: assign a free driver or queue the order.
function assignDriver(string orderId, string customerId, string restaurantId, DeliveryAddress address)
        returns error? {
    Delivery? existing = check findDeliveryByOrder(orderId);
    if existing is Delivery {
        log:printWarn("order already has a delivery, skipping", orderId = orderId);
        return;
    }
    Driver? driver = check claimDriver();
    if driver is () {
        check addPending({orderId, customerId, restaurantId, deliveryAddress: address, queuedAt: nowUtc()});
        log:printInfo("no driver free, order queued", orderId = orderId);
        return;
    }
    check createAssignment(orderId, customerId, restaurantId, address, driver);
}

# Gives waiting orders to free drivers, oldest order first, until one side runs out.
function assignPendingIfAny() returns error? {
    while true {
        Driver? driver = check claimDriver();
        if driver is () {
            return;
        }
        PendingDelivery? pending = check popOldestPending();
        if pending is () {
            // Nothing waiting: give the driver back.
            _ = check updateDriverStatus(driver.driverId, AVAILABLE, BUSY);
            return;
        }
        check createAssignment(pending.orderId, pending.customerId, pending.restaurantId,
                pending.deliveryAddress, driver);
    }
}

# Saves the delivery and publishes delivery.assigned. Frees the driver if saving fails.
function createAssignment(string orderId, string customerId, string restaurantId, DeliveryAddress address,
        Driver driver) returns error? {
    Delivery delivery = {
        deliveryId: "DEL-" + uuid:createType4AsString(),
        orderId,
        driverId: driver.driverId,
        customerId,
        restaurantId,
        deliveryAddress: address,
        status: ASSIGNED,
        assignedAt: nowUtc(),
        pickedUpAt: (),
        deliveredAt: ()
    };
    error? saved = insertDelivery(delivery);
    if saved is error {
        _ = check updateDriverStatus(driver.driverId, AVAILABLE, BUSY);
        return saved;
    }
    check publishAssigned(delivery, driver.name);
    log:printInfo("driver assigned", orderId = orderId, driverId = driver.driverId);
}

// ---------- Deliveries ----------

# Looks up the delivery for an order.
function getDelivery(string orderId) returns Delivery|error {
    Delivery? delivery = check findDeliveryByOrder(orderId);
    if delivery is () {
        return error NotFoundError(string `No delivery for order ${orderId} (not READY yet, or waiting for a driver)`);
    }
    return delivery;
}

# ASSIGNED -> PICKED_UP, then publishes delivery.picked-up.
function markPickedUp(string orderId) returns Delivery|error {
    Delivery delivery = check getDelivery(orderId);
    if delivery.status != ASSIGNED {
        return error ConflictError(string `Delivery is ${delivery.status}, expected ASSIGNED`);
    }
    delivery.status = PICKED_UP;
    delivery.pickedUpAt = nowUtc();
    boolean updated = check updateDelivery(delivery, ASSIGNED);
    if !updated {
        return error ConflictError("Delivery was updated at the same time, try again");
    }
    check publishPickedUp(delivery);
    return delivery;
}

# PICKED_UP -> DELIVERED, publishes delivery.completed, frees the driver.
function markDelivered(string orderId) returns Delivery|error {
    Delivery delivery = check getDelivery(orderId);
    if delivery.status != PICKED_UP {
        return error ConflictError(string `Delivery is ${delivery.status}, expected PICKED_UP`);
    }
    string now = nowUtc();
    string pickedUpAt = delivery.pickedUpAt ?: now;
    int durationMinutes = check minutesBetween(pickedUpAt, now);

    delivery.status = DELIVERED;
    delivery.deliveredAt = now;
    boolean updated = check updateDelivery(delivery, PICKED_UP);
    if !updated {
        return error ConflictError("Delivery was updated at the same time, try again");
    }
    check publishCompleted(delivery, durationMinutes);

    _ = check updateDriverStatus(delivery.driverId, AVAILABLE, BUSY);
    check assignPendingIfAny();
    return delivery;
}
