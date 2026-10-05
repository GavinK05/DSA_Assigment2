import ballerina/http;
import ballerina/log;

type ErrorResponse http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError;

service / on httpListener {

    # Health check used by Docker Compose.
    resource function get health() returns json {
        return {status: "UP", 'service: SERVICE_NAME};
    }

    # 1. Register a driver.
    resource function post drivers(@http:Payload NewDriver body) returns http:Created|ErrorResponse {
        Driver|error driver = registerDriver(body);
        if driver is error {
            return toErrorResponse(driver);
        }
        return <http:Created>{body: driver};
    }

    # 2. List drivers, optionally filtered by status.
    resource function get drivers(string? status) returns Driver[]|ErrorResponse {
        DriverStatus? filter = ();
        if status is DriverStatus {
            filter = status;
        } else if status is string {
            return <http:BadRequest>{body: errorBody("BAD_REQUEST", "status must be AVAILABLE, BUSY or OFFLINE")};
        }
        Driver[]|error drivers = findDrivers(filter);
        if drivers is error {
            return toErrorResponse(drivers);
        }
        return drivers;
    }

    # 3. Driver goes AVAILABLE or OFFLINE.
    resource function patch drivers/[string driverId]/status(@http:Payload DriverStatusUpdate body)
            returns Driver|ErrorResponse {
        Driver|error driver = changeDriverStatus(driverId, body.status);
        if driver is error {
            return toErrorResponse(driver);
        }
        return driver;
    }

    # 4. Update a driver's GPS location.
    resource function put drivers/[string driverId]/location(@http:Payload LocationUpdate body)
            returns Driver|ErrorResponse {
        Driver|error driver = updateLocation(driverId, body);
        if driver is error {
            return toErrorResponse(driver);
        }
        return driver;
    }

    # 5. Delivery status for an order.
    resource function get deliveries/[string orderId]() returns Delivery|ErrorResponse {
        Delivery|error delivery = getDelivery(orderId);
        if delivery is error {
            return toErrorResponse(delivery);
        }
        return delivery;
    }

    # 6. Driver collected the food.
    resource function post deliveries/[string orderId]/pickup() returns http:Ok|ErrorResponse {
        Delivery|error delivery = markPickedUp(orderId);
        if delivery is error {
            return toErrorResponse(delivery);
        }
        return <http:Ok>{body: delivery};
    }

    # 7. Driver dropped the food off.
    resource function post deliveries/[string orderId]/complete() returns http:Ok|ErrorResponse {
        Delivery|error delivery = markDelivered(orderId);
        if delivery is error {
            return toErrorResponse(delivery);
        }
        return <http:Ok>{body: delivery};
    }
}

# Maps a logic error to the HTTP response from README section 6.
function toErrorResponse(error err) returns ErrorResponse {
    if err is ValidationError {
        return <http:BadRequest>{body: errorBody("BAD_REQUEST", err.message())};
    }
    if err is NotFoundError {
        return <http:NotFound>{body: errorBody("NOT_FOUND", err.message())};
    }
    if err is ConflictError {
        return <http:Conflict>{body: errorBody("CONFLICT", err.message())};
    }
    log:printError("unexpected error", err);
    return <http:InternalServerError>{body: errorBody("INTERNAL_ERROR", "Something went wrong")};
}

# Builds the standard error body.
function errorBody(string code, string message) returns ErrorBody => {'error: code, message};
