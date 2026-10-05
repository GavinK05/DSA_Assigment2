import ballerina/http;

service /notifications on notificationHttpListener {

    resource function get [string notificationId]()
            returns Notification|http:NotFound|http:InternalServerError {

        Notification?|error result =
            findNotification(notificationId);

        if result is error {
            ErrorBody errorBody = {
                'error: "INTERNAL_ERROR",
                message: result.message()
            };

            return <http:InternalServerError> {
                body: errorBody
            };
        }

        if result is Notification {
            return result;
        }

        ErrorBody errorBody = {
            'error: "NOT_FOUND",
            message: "Notification "
                + notificationId
                + " does not exist"
        };

        return <http:NotFound> {
            body: errorBody
        };
    }

    resource function get .(string? recipientId, string? orderId)
            returns Notification[]|http:InternalServerError {

        Notification[]|error results =
            findNotifications(recipientId, orderId);

        if results is error {
            ErrorBody errorBody = {
                'error: "INTERNAL_ERROR",
                message: results.message()
            };

            return <http:InternalServerError> {
                body: errorBody
            };
        }

        return results;
    }
}

service /health on notificationHttpListener {

    resource function get .() returns json {
        return {
            "status": "UP",
            "service": "notification-service"
        };
    }
}