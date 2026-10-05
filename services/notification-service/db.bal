import ballerinax/mongodb;

final mongodb:Client mongoClient = check new ({
    connection: mongoUrl
});

function notificationsCol() returns mongodb:Collection|error {
    mongodb:Database db =
        check mongoClient->getDatabase("notification_db");

    return db->getCollection("notifications");
}

function processedEventsCol() returns mongodb:Collection|error {
    mongodb:Database db =
        check mongoClient->getDatabase("notification_db");

    return db->getCollection("processed_events");
}

function insertNotification(Notification notification) returns error? {
    mongodb:Collection col = check notificationsCol();

    check col->insertOne(notification);
}

function findNotification(string notificationId)
        returns Notification?|error {

    mongodb:Collection col = check notificationsCol();

    return col->findOne({
        notificationId: notificationId
    });
}

function hasProcessedEvent(string eventId)
        returns boolean|error {

    mongodb:Collection col = check processedEventsCol();

    ProcessedEvent? processedEvent =
        check col->findOne({
            eventId: eventId
        });

    return processedEvent is ProcessedEvent;
}

function saveProcessedEvent(ProcessedEvent processedEvent)
        returns error? {

    mongodb:Collection col = check processedEventsCol();

    check col->insertOne(processedEvent);
}

function findNotifications(string? recipientId, string? orderId)
        returns Notification[]|error {

    mongodb:Collection col = check notificationsCol();

    map<json> filter = {};

    if recipientId is string {
        filter["recipientId"] = recipientId;
    }

    if orderId is string {
        filter["orderId"] = orderId;
    }

    stream<Notification, error?> notificationStream =
        check col->find(filter, targetType = Notification);

    Notification[] notifications =
        check from Notification notification in notificationStream
        select notification;

    check notificationStream.close();

    return notifications;
}