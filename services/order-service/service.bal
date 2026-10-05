import ballerina/http; 

service / on new http:Listener(port) {
    # Health check used by docker-compose to determine if the service is ready to accept requests. Returns 200 OK if the service is healthy.
    resource function get health() returns json{
        return{status: "UP", "service": "order-service"};
}
# Creates a new order in CREATED status and saves it to MongoDB. Returns 201 Created with the order if successful, 400 Bad Request if the request is invalid, or 500 Internal Server Error if there was an error saving the order.
 resource function post orders(NewOrderRequest req)
            returns http:Created|http:BadRequest|http:InternalServerError {
        Order|error result = createOrder(req);
        if result is error {
            if result.message().startsWith("Order must have") {
                return <http:BadRequest>{body: {'error: "BAD_REQUEST", message: result.message()}};
            }
            return <http:InternalServerError>{body: {'error: "INTERNAL", message: result.message()}};
        }
        return <http:Created>{body: result};
    }
        # get an order by orderId.
        resource function get orders/[string orderId]()
            returns Order|http:NotFound|http:InternalServerError {
        Order?|error result = findOrder(orderId);
        if result is error {
            return <http:InternalServerError>{body: {'error: "INTERNAL", message: result.message()}};
        }
        if result is () {
            return <http:NotFound>{body: {'error: "NOT_FOUND", message: "Order " + orderId + " does not exist"}};
        }
        return result;
            }
        # List orders by one of customerId, restaurantId, or status.
    resource function get orders(string? customerId, string? restaurantId, string? status)
            returns Order[]|http:InternalServerError {
        map<json> filter = {};
        if customerId is string {
            filter["customerId"] = customerId;
        }
        if restaurantId is string {
            filter["restaurantId"] = restaurantId;
        }
        if status is string {
            filter["status"] = status;
        }
        Order[]|error result = findOrders(filter);
        if result is error {
            return <http:InternalServerError>{body: {'error: "INTERNAL", message: result.message()}};
        }
        return result;
    }
    # Customer cancels an order. 
    resource function post orders/[string orderId]/cancel()
            returns Order|http:NotFound|http:Conflict|http:InternalServerError {
        Order|error result = changeStatus(orderId, CANCELLED, "Cancelled by customer");
        if result is InvalidTransitionError {
            return <http:Conflict>{body: {'error: "CONFLICT", message: result.message()}};
        }
        if result is error {
            if result.message().startsWith("NOT_FOUND") {
                return <http:NotFound>{body: {'error: "NOT_FOUND", message: "Order " + orderId + " does not exist"}};
            }
            return <http:InternalServerError>{body: {'error: "INTERNAL", message: result.message()}};
        }
        return result;
    }
    # Get the status history of an order.
resource function get orders/[string orderId]/history()
            returns StatusEntry[]|http:NotFound|http:InternalServerError {
                Order?|error result = findOrder(orderId);
                if result is error {
                    return <http:InternalServerError>{body: {'error: "INTERNAL", message: result.message()}};
                }
                if result is () {
                    return <http:NotFound>{body: {'error: "NOT_FOUND", message: "Order " + orderId + " does not exist"}};
                }
                return result.statusHistory;
            } // note that Endpoint 2 returns the whole order and endpoint 5 returns just the timeline list inside it via return result.statusHistory.}
