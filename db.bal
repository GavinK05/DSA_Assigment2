import ballerinax/mongodb;

const string DRIVERS = "drivers";
const string DELIVERIES = "deliveries";
const string PENDING_DELIVERIES = "pending_deliveries";
const string PROCESSED = "processed_events";

final mongodb:Client mongoClient = check new ({connection: mongoUrl});

# Returns a collection in delivery db.
function collection(string name) returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient -> getDatabase(DB_NAME);
    return db->getCollection(name);
}

# Unique indexes so duplicates fail at the database too.
function ensureIndexes() returns error? {
    mongodb:Collection drivers = check collection(DRIVERS);
    check drivers->createIndex({driverId: 1}, {unique: true});
    mongodb:Collection deliveries = check collection(DELIVERIES);
    check deliveries->createIndex({orderId: 1}, {unique: true});
    mongodb:Collection pending = check collection(PENDING);
    check pending->createIndex({orderId: 1}, {unique: true});
    mongodb:Collection processed = check collection(PROCESSED);
    check processed->createIndex({eventId: 1}, {unique: true});
}

//----drivers----

# Inserts a new driver.
function insertDriver(Driver driver) returns error? {
    mongodb:Collection drivers = check collection(DRIVERS);
    check drivers->insertOne(driver);
}

#Finds one driver by id.
function findDriver(string driverId) returns Driver|error? {
    mongodb:Collection drivers = check collection(DRIVERS);
    Driver? driver = check drivers->findOne({driverId}, {}, {_id: 0});
    return driver;
}

#Lists drivers, optionally filtered by status.
function findDrivers(DriverStatus? status) returns Driver[]|error{
    mongodb:Collection drivers = check collection(DRIVERS);
    map<json> filter = status is () ? {} : {status};
    stream<Driver, error?> result = check drivers->find(filter, {}, {_id: 0});
    return from Driver d in result select d;
}

#The AVAILABLE driver who has been waiting the longest.
function findAvailableDriver() returns Driver|error? {
    mongodb:Collection drivers = check collection(DRIVERS);
    Driver? driver = check drivers->findOne({status: AVAILABLE}, {sort: {updatedAt: 1}}, {_id: 0});
    return driver;
}

# Sets a driver's status. If 'expected' is given only updates when the current status matches
# (this is what stops two order grabbing the same driver). Retruns true if a driverwas updated.
function uupdateDriverStatus(string driver)