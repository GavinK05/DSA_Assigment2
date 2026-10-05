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

// a restaurant is open from its opening time up to, but not including, its closing time.
// overnight hours are not supported, so a restaurant that opens at 10 PM and closes at 2 AM is considered closed at 1 AM.
// we dont got those typa resturants out here yk
public function isOpenNow(OpeningHours[] openingHours) returns boolean {
    time:Civil currentTime = time:utcToCivil(time:utcNow());
    time:DayOfWeek? currentDay = currentTime.dayOfWeek;
    if currentDay is () {
        return false;
    }

    string currentHour = string `${currentTime.hour}`;
    string currentMinute = string `${currentTime.minute}`;
    if currentTime.hour < 10 {
        currentHour = "0" + currentHour;
    }
    if currentTime.minute < 10 {
        currentMinute = "0" + currentMinute;
    }
    string currentClockTime = currentHour + ":" + currentMinute;

    foreach OpeningHours hours in openingHours {
        if !isSameDay(currentDay, hours.day) {
            continue;
        }
        if hours.open >= hours.close {
            continue;
        }
        if currentClockTime >= hours.open && currentClockTime < hours.close {
            return true;
        }
    }
    return false;
}

// there gotta be a library for this man 😭
function isSameDay(time:DayOfWeek currentDay, Day openingDay) returns boolean {
    if currentDay == time:SUNDAY {
        return openingDay == SUNDAY;
    }
    if currentDay == time:MONDAY {
        return openingDay == MONDAY;
    }
    if currentDay == time:TUESDAY {
        return openingDay == TUESDAY;
    }
    if currentDay == time:WEDNESDAY {
        return openingDay == WEDNESDAY;
    }
    if currentDay == time:THURSDAY {
        return openingDay == THURSDAY;
    }
    if currentDay == time:FRIDAY {
        return openingDay == FRIDAY;
    }
    if currentDay == time:SATURDAY {
        return openingDay == SATURDAY;
    }
}
