import ballerina/log;
import ballerina/time;
import ballerina/uuid;

function createNotification(
        string orderId,
        string recipientId,
        string recipientType,
        NotificationChannel channel,
        string message,
        string eventType
    ) returns error? {

    Notification notification = {
        notificationId: "NOT-" + uuid:createType4AsString(),
        orderId: orderId,
        recipientId: recipientId,
        recipientType: recipientType,
        channel: channel,
        message: message,
        eventType: eventType,
        createdAt: time:utcToString(time:utcNow())
    };

    check insertNotification(notification);

    log:printInfo(
        channel.toString()
        + " notification sent to "
        + recipientType
        + " "
        + recipientId
        + ": "
        + message
    );
}

function handleNotificationEvent(EventEnvelope event) returns error? {

    if check hasProcessedEvent(event.eventId) {
        log:printInfo(
            "Skipping already processed event: " + event.eventId
        );
        return;
    }

    match event.eventType {

        "orders.created" => {
            OrderCreatedData data =
                check event.data.cloneWithType();

            check createNotification(
                event.orderId,
                data.restaurantId,
                "RESTAURANT",
                PUSH,
                "A new order has been placed.",
                event.eventType
            );
        }

        "orders.status-changed" => {
            OrderStatusChangedData data =
                check event.data.cloneWithType();

            check createNotification(
                event.orderId,
                data.customerId,
                "CUSTOMER",
                EMAIL,
                "Your order status changed to " + data.toStatus,
                event.eventType
            );
        }

        "restaurant.order-updated" => {
            RestaurantOrderUpdatedData data =
                check event.data.cloneWithType();

            check createNotification(
                event.orderId,
                data.restaurantId,
                "RESTAURANT",
                PUSH,
                "Restaurant order status updated to " + data.status,
                event.eventType
            );
        }

        "restaurant.order-validated" => {
            OrderValidatedData data =
                check event.data.cloneWithType();

            string message = "Your order was accepted by the restaurant.";

            if !data.accepted {
                message = "Your order was rejected: " + data.reason;
            }

            check createNotification(
                event.orderId,
                data.customerId,
                "CUSTOMER",
                EMAIL,
                message,
                event.eventType
            );
        }

        "payments.completed" => {
            PaymentCompletedData data =
                check event.data.cloneWithType();

            check createNotification(
                event.orderId,
                data.customerId,
                "CUSTOMER",
                EMAIL,
                "Payment completed successfully.",
                event.eventType
            );
        }

        "payments.failed" => {
            PaymentFailedData data =
                check event.data.cloneWithType();

            check createNotification(
                event.orderId,
                data.customerId,
                "CUSTOMER",
                EMAIL,
                "Payment failed: " + data.reason,
                event.eventType
            );
        }

        "delivery.assigned" => {
            DeliveryAssignedData data =
                check event.data.cloneWithType();

            check createNotification(
                event.orderId,
                data.driverId,
                "DRIVER",
                SMS,
                "You have been assigned a new delivery.",
                event.eventType
            );

            check createNotification(
                event.orderId,
                data.customerId,
                "CUSTOMER",
                PUSH,
                "A driver has been assigned to your order.",
                event.eventType
            );
        }

        "delivery.picked-up" => {
            DeliveryPickedUpData data =
                check event.data.cloneWithType();

            check createNotification(
                event.orderId,
                data.customerId,
                "CUSTOMER",
                PUSH,
                "Your order has been picked up.",
                event.eventType
            );
        }

        "delivery.completed" => {
            DeliveryCompletedData data =
                check event.data.cloneWithType();

            check createNotification(
                event.orderId,
                data.customerId,
                "CUSTOMER",
                EMAIL,
                "Your order has been delivered.",
                event.eventType
            );

            check createNotification(
                event.orderId,
                data.restaurantId,
                "RESTAURANT",
                PUSH,
                "Order delivery has been completed.",
                event.eventType
            );
        }

        _ => {
            log:printWarn(
                "Unsupported event type: " + event.eventType
            );
        }
    }

    check saveProcessedEvent({
        eventId: event.eventId,
        processedAt: time:utcToString(time:utcNow())
    });
}