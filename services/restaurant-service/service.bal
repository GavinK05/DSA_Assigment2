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
}
