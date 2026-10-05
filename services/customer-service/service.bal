import ballerina/http;

// Maps a logic/db error to the contract's error response.
function errorResponse(error err, string notFoundMessage) returns http:Response {
    http:Response response = new;
    string code = err.message();
    ErrorResponse body;
    if code == "NOT_FOUND" {
        response.statusCode = 404;
        body = {'error: "NOT_FOUND", message: notFoundMessage};
    } else if code == "ADDRESS_NOT_FOUND" {
        response.statusCode = 404;
        body = {'error: "NOT_FOUND", message: "Address does not exist for this customer"};
    } else if code == "DUPLICATE" {
        response.statusCode = 409;
        body = {'error: "DUPLICATE", message: "A customer with this email already exists"};
    } else if code.startsWith("INVALID_REQUEST:") {
        response.statusCode = 400;
        body = {'error: "INVALID_REQUEST", message: code.substring(16)};
    } else {
        response.statusCode = 500;
        body = {'error: "DATABASE_ERROR", message: code};
    }
    response.setPayload(body);
    return response;
}

function jsonResponse(int status, json payload) returns http:Response {
    http:Response response = new;
    response.statusCode = status;
    response.setPayload(payload);
    return response;
}

service / on httpListener {

    # Reports that the customer service is available.
    # + return - Service health information.
    resource function get health() returns HealthResponse {
        return {status: "UP", 'service: "customer-service"};
    }

    # Registers a customer; 409 if the email already exists.
    # + request - Registration data.
    # + return - 201 with the customer, or an error response.
    resource function post customers(@http:Payload CustomerCreateRequest request) returns http:Response {
        Customer|error result = registerCustomer(request);
        if result is error {
            return errorResponse(result, "");
        }
        return jsonResponse(201, result.toJson());
    }

    # Gets one customer profile.
    # + customerId - Customer ID from the path.
    # + return - The customer, or 404.
    resource function get customers/[string customerId]() returns http:Response {
        Customer|error result = findCustomer(customerId);
        if result is error {
            return errorResponse(result, "Customer " + customerId + " does not exist");
        }
        return jsonResponse(200, result.toJson());
    }

    # Updates a customer's name and/or phone.
    # + customerId - Customer ID from the path.
    # + request - Fields to change.
    # + return - The updated customer, or an error response.
    resource function put customers/[string customerId](@http:Payload CustomerUpdateRequest request) returns http:Response {
        Customer|error result = changeCustomer(customerId, request);
        if result is error {
            return errorResponse(result, "Customer " + customerId + " does not exist");
        }
        return jsonResponse(200, result.toJson());
    }

    # Adds a delivery address to a customer.
    # + customerId - Customer ID from the path.
    # + request - Address data.
    # + return - 201 with the address, or an error response.
    resource function post customers/[string customerId]/addresses(@http:Payload AddressRequest request) returns http:Response {
        Address|error result = createAddress(customerId, request);
        if result is error {
            return errorResponse(result, "Customer " + customerId + " does not exist");
        }
        return jsonResponse(201, result.toJson());
    }

    # Lists a customer's addresses.
    # + customerId - Customer ID from the path.
    # + return - The addresses, or 404 if the customer does not exist.
    resource function get customers/[string customerId]/addresses() returns http:Response {
        Customer|error result = findCustomer(customerId);
        if result is error {
            return errorResponse(result, "Customer " + customerId + " does not exist");
        }
        return jsonResponse(200, result.addresses.toJson());
    }

    # Removes one address from a customer.
    # + customerId - Customer ID from the path.
    # + addressId - Address ID from the path.
    # + return - 204 on success, or an error response.
    resource function delete customers/[string customerId]/addresses/[string addressId]() returns http:Response {
        error? result = removeAddress(customerId, addressId);
        if result is error {
            return errorResponse(result, "Customer " + customerId + " does not exist");
        }
        http:Response response = new;
        response.statusCode = 204;
        return response;
    }

    # Returns a customer's order history built from Kafka events.
    # + customerId - Customer ID from the path.
    # + return - The orders, newest first, or 404 if the customer does not exist.
    resource function get customers/[string customerId]/orders() returns http:Response {
        Customer|error customer = findCustomer(customerId);
        if customer is error {
            return errorResponse(customer, "Customer " + customerId + " does not exist");
        }
        OrderHistoryEntry[]|error orders = findOrderHistory(customerId);
        if orders is error {
            return errorResponse(orders, "");
        }
        return jsonResponse(200, orders.toJson());
    }
}
