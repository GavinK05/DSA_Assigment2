import ballerina/http;
import ballerina/time;

service / on httpListener {

# Reports that the restaurant service is available.
# + return - Service health information.
    // this is similar to a Python route such as @app.get("/health").
    resource function get health() returns HealthResponse {
        return {
            status: "UP",
            'service: "restaurant-service"
        };
    }

# Registers a restaurant and returns its generated restaurant ID.
# + request - Restaurant data from the request body.
# + return - HTTP response containing the created restaurant or an error.
    // in Python, this is similar to a Flask route that receives JSON.
    // defined these in types.bal so they calm for reuse here.
    resource function post restaurants(@http:Payload RestaurantCreateRequest request) returns http:Response {
        Restaurant|error result = createRestaurant(request);
        if result is error {
            // We create the HTTP response manually so we can choose its status code and JSON body.
            http:Response response = new;
            if result.message() == "DUPLICATE" {
                response.statusCode = 409;
                ErrorResponse errorResponse = {
                    'error: "DUPLICATE",
                    message: "A restaurant with the same name and city already exists"
                };
                response.setPayload(errorResponse);
            } else if result.message().startsWith("INVALID_REQUEST:") {
                response.statusCode = 400;
                ErrorResponse errorResponse = {
                    'error: "INVALID_REQUEST",
                    message: result.message().substring(16)
                };
                response.setPayload(errorResponse);
            } else {
                response.statusCode = 500;
                ErrorResponse errorResponse = {
                    'error: "DATABASE_ERROR",
                    message: result.message()
                };
                response.setPayload(errorResponse);
            }
            return response;
        }

        http:Response response = new;
        // 201 means that a new record was created successfully.
        response.statusCode = 201;
        // and then we convert the Restaurant record into the JSON response body.
        response.setPayload(result);
        return response;
    }

# Retrieves one restaurant and its current menu.
# + restaurantId - Restaurant ID from the path.
# + return - HTTP response containing the restaurant or an error.
    // This is similar to Flask's /restaurants/<restaurant_id> route.
    resource function get restaurants/[string restaurantId]() returns http:Response {
        Restaurant|error result = findRestaurant(restaurantId);

        if result is error {
            http:Response response = new;
            ErrorResponse errorResponse;
            if result.message() == "NOT_FOUND" {
                response.statusCode = 404;
                errorResponse = {
                    'error: "NOT_FOUND",
                    message: "Restaurant " + restaurantId + " does not exist"
                };
            } else {
                response.statusCode = 500;
                errorResponse = {
                    'error: "DATABASE_ERROR",
                    message: result.message()
                };
            }
            response.setPayload(errorResponse);
            return response;
        }

        http:Response response = new;
        response.statusCode = 200;
        response.setPayload(result);
        return response;
    }

# Lists restaurants and optionally filters to those currently open.
# + openNow - Optional boolean filter.
# + return - HTTP response containing matching restaurants or an error.
    // openNow=true keeps only restaurants accepted by isOpenNow.
    resource function get restaurants(@http:Query string? openNow) returns http:Response {
        Restaurant[]|error result = findRestaurants();

        if result is error {
            http:Response response = new;
            response.statusCode = 500;
            ErrorResponse errorResponse = {
                'error: "DATABASE_ERROR",
                message: result.message()
            };
            response.setPayload(errorResponse);
            return response;
        }

        Restaurant[] restaurants = result;
        if openNow is string && openNow != "true" && openNow != "false" {
            return menuErrorResponse(400, "INVALID_REQUEST", "openNow must be true or false");
        }
        if openNow is string && openNow == "true" {
            Restaurant[] openRestaurants = [];
            foreach Restaurant restaurant in restaurants {
                if isOpenNow(restaurant.openingHours) {
                    openRestaurants.push(restaurant);
                }
            }
            restaurants = openRestaurants;
        }

        http:Response response = new;
        response.statusCode = 200;
        response.setPayload(restaurants);
        return response;
    }

# Replaces a restaurant's opening-hours schedule after validating it.
# + restaurantId - Restaurant ID from the path.
# + openingHours - New weekly schedule from the request body.
# + return - HTTP response containing the updated restaurant or an error.
    resource function put restaurants/[string restaurantId]/hours(
            @http:Payload OpeningHours[] openingHours
    ) returns http:Response {
        error? validationResult = validateOpeningHours(openingHours);
        if validationResult is error {
            return menuErrorResponse(400, "INVALID_REQUEST", validationResult.message());
        }
        Restaurant|error result = updateHours(restaurantId, openingHours);

        if result is error {
            http:Response response = new;
            ErrorResponse errorResponse;
            if result.message() == "NOT_FOUND" {
                response.statusCode = 404;
                errorResponse = {
                    'error: "NOT_FOUND",
                    message: "Restaurant " + restaurantId + " does not exist"
                };
            } else {
                response.statusCode = 500;
                errorResponse = {
                    'error: "DATABASE_ERROR",
                    message: result.message()
                };
            }
            response.setPayload(errorResponse);
            return response;
        }

        http:Response response = new;
        response.statusCode = 200;
        response.setPayload(result);
        return response;
    }

# Adds a menu item when its ID is not already in the restaurant menu.
# + restaurantId - Restaurant ID from the path.
# + menuItem - Menu item from the request body.
# + return - HTTP response containing the updated restaurant or an error.
    resource function post restaurants/[string restaurantId]/menu(
            @http:Payload MenuItem menuItem
    ) returns http:Response {
        error? validationResult = validateMenuItem(menuItem);
        if validationResult is error {
            return menuErrorResponse(400, "INVALID_REQUEST", validationResult.message());
        }
        Restaurant|error result = addMenuItem(restaurantId, menuItem);
        return menuResultResponse(result, restaurantId, menuItem.itemId, 201);
    }

# Updates a menu item identified by the URL.
# + restaurantId - Restaurant ID from the path.
# + itemId - Menu item ID from the path.
# + menuItem - Updated menu item from the request body.
# + return - HTTP response containing the updated restaurant or an error.
    resource function put restaurants/[string restaurantId]/menu/[string itemId](
            @http:Payload MenuItem menuItem
    ) returns http:Response {
        error? validationResult = validateMenuItem(menuItem);
        if validationResult is error {
            return menuErrorResponse(400, "INVALID_REQUEST", validationResult.message());
        }
        if menuItem.itemId != itemId {
            return menuErrorResponse(400, "INVALID_REQUEST", "The itemId in the body must match the URL");
        }
        Restaurant|error result = updateMenuItem(restaurantId, itemId, menuItem);
        return menuResultResponse(result, restaurantId, itemId, 200);
    }

# Removes a menu item identified by the URL.
# + restaurantId - Restaurant ID from the path.
# + itemId - Menu item ID from the path.
# + return - HTTP response containing the updated restaurant or an error.
    resource function delete restaurants/[string restaurantId]/menu/[string itemId]() returns http:Response {
        Restaurant|error result = removeMenuItem(restaurantId, itemId);
        return menuResultResponse(result, restaurantId, itemId, 200);
    }

# Lists the kitchen queue for a restaurant, optionally filtered by status.
# + restaurantId - Restaurant ID from the path.
# + status - Optional kitchen order status filter.
# + return - HTTP response containing matching kitchen orders or an error.
    resource function get restaurants/[string restaurantId]/orders(@http:Query string? status) returns http:Response {
        Restaurant|error restaurantResult = findRestaurant(restaurantId);
        if restaurantResult is error {
            if restaurantResult.message() == "NOT_FOUND" {
                return menuErrorResponse(404, "NOT_FOUND", "Restaurant " + restaurantId + " does not exist");
            }
            return menuErrorResponse(500, "DATABASE_ERROR", restaurantResult.message());
        }
        if status is string && !isValidKitchenStatusFilter(status) {
            return menuErrorResponse(400, "INVALID_REQUEST", "Unsupported kitchen order status: " + status);
        }
        KitchenOrder[]|error orders = findKitchenOrders(restaurantId, status);
        if orders is error {
            return menuErrorResponse(500, "DATABASE_ERROR", orders.message());
        }
        KitchenOrder[] visibleOrders = [];
        foreach KitchenOrder kitchenOrder in orders {
            if status is string || isActiveKitchenStatus(kitchenOrder.status) {
                visibleOrders.push(kitchenOrder);
            }
        }
        http:Response response = new;
        response.statusCode = 200;
        response.setPayload(visibleOrders);
        return response;
    }

# Changes a kitchen order status and publishes the resulting restaurant fact.
# + restaurantId - Restaurant ID from the path.
# + orderId - Kitchen order ID from the path.
# + request - Requested kitchen status from the request body.
# + return - HTTP response containing the updated order or an error.
    resource function patch restaurants/[string restaurantId]/orders/[string orderId](
            @http:Payload KitchenOrderStatusUpdate request
    ) returns http:Response {
        KitchenOrder|error kitchenOrderResult = findKitchenOrder(restaurantId, orderId);
        if kitchenOrderResult is error {
            if kitchenOrderResult.message() == "ORDER_NOT_FOUND" {
                return menuErrorResponse(404, "NOT_FOUND", "Kitchen order " + orderId + " does not exist");
            }
            return menuErrorResponse(500, "DATABASE_ERROR", kitchenOrderResult.message());
        }
        KitchenOrder kitchenOrder = kitchenOrderResult;
        if !isValidKitchenTransition(kitchenOrder.status, request.status) {
            return menuErrorResponse(409, "INVALID_STATE", "Kitchen order cannot move from " + kitchenOrder.status.toString() + " to " + request.status.toString());
        }

        KitchenOrderStatus nextStatus;
        if request.status == "PREPARING" {
            nextStatus = "PREPARING";
        } else if request.status == "READY" {
            nextStatus = "READY";
        } else {
            nextStatus = "REJECTED";
        }

        string updatedAt = time:utcToString(time:utcNow());
        KitchenOrder|error updatedOrder = updateKitchenOrderStatus(
            restaurantId,
            orderId,
            kitchenOrder.status,
            nextStatus,
            updatedAt
        );
        if updatedOrder is error {
            if updatedOrder.message() == "CONFLICT" {
                return menuErrorResponse(409, "INVALID_STATE", "Kitchen order was changed by another request");
            }
            if updatedOrder.message() == "ORDER_NOT_FOUND" {
                return menuErrorResponse(404, "NOT_FOUND", "Kitchen order " + orderId + " does not exist");
            }
            return menuErrorResponse(500, "DATABASE_ERROR", updatedOrder.message());
        }

        error? publishResult = publishOrderUpdated(orderId, restaurantId, request.status);
        if publishResult is error {
            return menuErrorResponse(500, "KAFKA_ERROR", publishResult.message());
        }
        http:Response response = new;
        response.statusCode = 200;
        response.setPayload(updatedOrder);
        return response;
    }

}

function isValidKitchenStatusFilter(string status) returns boolean {
    return status == "AWAITING_CONFIRMATION" || status == "CONFIRMED" || status == "PREPARING" ||
        status == "READY" || status == "REJECTED" || status == "CANCELLED";
}

function isActiveKitchenStatus(KitchenOrderStatus status) returns boolean {
    return status == "CONFIRMED" || status == "PREPARING" || status == "READY";
}

// we use one response helper so all the menu routes return errors the same way.
function menuResultResponse(Restaurant|error result, string restaurantId, string itemId, int successStatus) returns http:Response {
    if result is error {
        if result.message() == "NOT_FOUND" {
            return menuErrorResponse(404, "NOT_FOUND", "Restaurant " + restaurantId + " does not exist");
        }
        if result.message() == "ITEM_NOT_FOUND" {
            return menuErrorResponse(404, "NOT_FOUND", "Menu item " + itemId + " does not exist");
        }
        if result.message() == "DUPLICATE" {
            return menuErrorResponse(409, "DUPLICATE", "Menu item " + itemId + " already exists");
        }
        return menuErrorResponse(500, "DATABASE_ERROR", result.message());
    }

    http:Response response = new;
    response.statusCode = successStatus;
    response.setPayload(result);
    return response;
}

function menuErrorResponse(int statusCode, string errorCode, string message) returns http:Response {
    http:Response response = new;
    response.statusCode = statusCode;
    response.setPayload(<ErrorResponse>{'error: errorCode, message: message});
    return response;
}
