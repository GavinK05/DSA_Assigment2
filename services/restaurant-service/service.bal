import ballerina/http;

service / on httpListener {

    // this is similar to a Python route such as @app.get("/health").
    resource function get health() returns HealthResponse {
        return {
            status: "UP",
            'service: "restaurant-service"
        };
    }

    // read the request, call the business logic, and return the HTTP result.
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
            } else {
                // Any other error here means the client's request was invalid.
                response.statusCode = 400;
                ErrorResponse errorResponse = {
                    'error: "INVALID_REQUEST",
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

    // The [string restaurantId] part reads the ID from the URL.
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

    // Without openNow this returns every restaurant.
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

    //
    resource function put restaurants/[string restaurantId]/hours(
            @http:Payload OpeningHours[] openingHours
    ) returns http:Response {
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

    resource function delete restaurants/[string restaurantId]/menu/[string itemId]() returns http:Response {
        Restaurant|error result = removeMenuItem(restaurantId, itemId);
        return menuResultResponse(result, restaurantId, itemId, 200);
    }

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
