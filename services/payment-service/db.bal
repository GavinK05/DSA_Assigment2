import ballerinax/mongodb;

final mongodb:Client mongoClient = check new ({connection: mongoUrl});

function paymentsCol() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase("payment_db");
    return db->getCollection("payments");
}

function processedEventsCol() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase("payment_db");
    return db->getCollection("processed_events");
}

function insertPayment(Payment payment) returns error? {
    mongodb:Collection col = check paymentsCol();
    check col->insertOne(payment);
}

function findPayment(string paymentId) returns Payment?|error {
    mongodb:Collection col = check paymentsCol();
    return col->findOne({paymentId: paymentId});
}

function findPaymentByOrder(string orderId) returns Payment?|error {
    mongodb:Collection col = check paymentsCol();
    return col->findOne({orderId: orderId});
}

function hasProcessedEvent(string eventId) returns boolean|error {
    mongodb:Collection col = check processedEventsCol();
    ProcessedEvent? event = check col->findOne({eventId: eventId});

    return event is ProcessedEvent;
}

function saveProcessedEvent(ProcessedEvent event) returns error? {
    mongodb:Collection col = check processedEventsCol();
    check col->insertOne(event);
}

function findPayments(string? orderId, string? customerId)
        returns Payment[]|error {

    mongodb:Collection col = check paymentsCol();

    map<json> filter = {};

    if orderId is string {
        filter["orderId"] = orderId;
    }

    if customerId is string {
        filter["customerId"] = customerId;
    }

    stream<Payment, error?> paymentStream =
        check col->find(filter, targetType = Payment);

    Payment[] payments =
        check from Payment payment in paymentStream
        select payment;

    check paymentStream.close();

    return payments;
}