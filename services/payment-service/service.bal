import ballerina/http;

service /payments on paymentHttpListener {

    resource function get [string paymentId]()
            returns Payment|http:NotFound|http:InternalServerError {

        Payment?|error result = findPayment(paymentId);

        if result is error {
            ErrorBody errorBody = {
                'error: "INTERNAL_ERROR",
                message: result.message()
            };

            return <http:InternalServerError> {
                body: errorBody
            };
        }

        if result is Payment {
            return result;
        }

        ErrorBody errorBody = {
            'error: "NOT_FOUND",
            message: "Payment " + paymentId + " does not exist"
        };

        return <http:NotFound> {
            body: errorBody
        };
    }

    resource function get .(string? orderId, string? customerId) 
            returns Payment[]|http:InternalServerError {

        Payment[]|error results =
            findPayments(orderId, customerId);

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

service /health on paymentHttpListener {

    resource function get .() returns json {
        return {
            "status": "UP",
            "service": "payment-service"
        };
    }
}