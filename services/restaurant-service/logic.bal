import ballerina/time;
import ballerina/uuid;

// ok this creates the univarsal unique id (uuid) for the restaurant
// and adds the prefix RES- to it so we know its a restaurant id
// then it creates the restaurant record and adds the current time to it
public function createRestaurant(RestaurantCreateRequest request) returns Restaurant|error {
    check validateRestaurant(request);

    string uuidValue = uuid:createType4AsString();
    Restaurant restaurant = {
        restaurantId: "RES-" + uuidValue,
        name: request.name,
        cuisine: request.cuisine,
        address: request.address,
        openingHours: request.openingHours,
        menu: request.menu,
        createdAt: time:utcToString(time:utcNow())
    };

    return insertRestaurant(restaurant);
}

// this just to check valididty so basic error handling so users dont add
// invalid data like negative price or stock or invalid lat and lng
function validateRestaurant(RestaurantCreateRequest request) returns error? {
    if request.name == "" {
        return error("Restaurant name is required");
    }
    if request.cuisine == "" {
        return error("Restaurant cuisine is required");
    }
    decimal minimumLatitude = -90;
    decimal maximumLatitude = 90;
    decimal minimumLongitude = -180;
    decimal maximumLongitude = 180;

    if request.address.lat < minimumLatitude || request.address.lat > maximumLatitude {
        return error("Latitude must be between -90 and 90");
    }
    if request.address.lng < minimumLongitude || request.address.lng > maximumLongitude {
        return error("Longitude must be between -180 and 180");
    }

    foreach MenuItem item in request.menu {
        decimal minimumPrice = 0;
        if item.price < minimumPrice {
            return error("Menu item price cannot be negative");
        }
        if item.stock < 0 {
            return error("Menu item stock cannot be negative");
        }
    }
}
