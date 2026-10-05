import ballerina/http;

function jsonResponse(int status, json payload) returns http:Response {
    http:Response response = new;
    response.statusCode = status;
    response.setPayload(payload);
    return response;
}

function failure(error err, string notFoundMessage) returns http:Response {
    if err.message() == "NOT_FOUND" {
        ErrorResponse body = {'error: "NOT_FOUND", message: notFoundMessage};
        return jsonResponse(404, body.toJson());
    }
    ErrorResponse body = {'error: "DATABASE_ERROR", message: err.message()};
    return jsonResponse(500, body.toJson());
}

service / on httpListener {

    # Reports that the admin service is available.
    # + return - Service health information.
    resource function get health() returns HealthResponse {
        return {status: "UP", 'service: "admin-service"};
    }

    # Order counts per status and total revenue.
    # + return - The orders report.
    resource function get admin/reports/orders() returns http:Response {
        OrderStat[]|error orders = findOrderStats();
        if orders is error {
            return failure(orders, "");
        }
        RestaurantStat[]|error restaurants = findRestaurantStats();
        if restaurants is error {
            return failure(restaurants, "");
        }
        return jsonResponse(200, buildOrdersReport(orders, restaurants).toJson());
    }

    # Stats for every restaurant.
    # + return - One row per restaurant.
    resource function get admin/reports/restaurants() returns http:Response {
        RestaurantStat[]|error restaurants = findRestaurantStats();
        if restaurants is error {
            return failure(restaurants, "");
        }
        return jsonResponse(200, restaurants.toJson());
    }

    # Stats for one restaurant.
    # + restaurantId - Restaurant ID from the path.
    # + return - The stats, or 404 if no events have been seen for it.
    resource function get admin/reports/restaurants/[string restaurantId]() returns http:Response {
        RestaurantStat|error stat = findRestaurantStat(restaurantId);
        if stat is error {
            return failure(stat, "No statistics for restaurant " + restaurantId);
        }
        return jsonResponse(200, stat.toJson());
    }

    # Deliveries completed and average delivery minutes per driver.
    # + return - One row per driver.
    resource function get admin/reports/deliveries() returns http:Response {
        DriverStat[]|error drivers = findDriverStats();
        if drivers is error {
            return failure(drivers, "");
        }
        return jsonResponse(200, buildDeliveryReport(drivers).toJson());
    }

    # Payment success vs failure counts and amounts.
    # + return - The payments report.
    resource function get admin/reports/payments() returns http:Response {
        PaymentStat[]|error payments = findPaymentStats();
        if payments is error {
            return failure(payments, "");
        }
        return jsonResponse(200, buildPaymentsReport(payments).toJson());
    }
}
