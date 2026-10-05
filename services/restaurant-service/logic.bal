import ballerina/time;
import ballerina/uuid;

// ok this creates the univarsal unique id (uuid) for the restaurant
// and adds the prefix RES- to it so we know its a restaurant id
// then it creates the restaurant record and adds the current time to it
# Validates and stores a restaurant supplied through the registration endpoint.
# + request - Restaurant details from the registration request.
# + return - The saved restaurant or an error.
public function createRestaurant(RestaurantCreateRequest request) returns Restaurant|error {
    error? validationResult = validateRestaurant(request);
    if validationResult is error {
        return error("INVALID_REQUEST:" + validationResult.message());
    }

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

    check validateOpeningHours(request.openingHours);

    string[] seenItemIds = [];
    foreach MenuItem item in request.menu {
        check validateMenuItem(item);
        foreach string seenItemId in seenItemIds {
            if seenItemId == item.itemId {
                return error("Duplicate menu item ID: " + item.itemId);
            }
        }
        seenItemIds.push(item.itemId);
    }
}

// we keep the menu checks here so all the menu routes use the same rules.
// no negative prices or stock, and the name cannot just be blank.
function validateMenuItem(MenuItem menuItem) returns error? {
    if menuItem.itemId.trim() == "" {
        return error("Menu item ID is required");
    }
    if menuItem.name == "" {
        return error("Menu item name is required");
    }
    decimal minimumMenuPrice = 0;
    if menuItem.price < minimumMenuPrice {
        return error("Menu item price cannot be negative");
    }
    if menuItem.stock < 0 {
        return error("Menu item stock cannot be negative");
    }
}

// restaurantId and requestedItems come from the order request/event.
// we read the restaurant from MongoDB so the customer cannot send their own price.
// the total is exact decimal addition in NAD, with no extra rounding added.
# Checks order contents against current restaurant hours, availability, stock, and prices.
# + restaurantId - Restaurant that owns the requested menu items.
# + requestedItems - Item IDs and quantities from the order event.
# + return - Accepted priced items or a rejection result, or a database error.
public function validateAndPriceOrder(string restaurantId, OrderItemRequest[] requestedItems) returns OrderValidationResult|error {
    // this gets the current restaurant record from the restaurants collection.
    Restaurant|error restaurantResult = findRestaurant(restaurantId);
    if restaurantResult is error {
        if restaurantResult.message() == "NOT_FOUND" {
            return rejectedOrder("RESTAURANT_NOT_FOUND");
        }
        return restaurantResult;
    }
    Restaurant restaurant = restaurantResult;
    if !isOpenNow(restaurant.openingHours) {
        return rejectedOrder("RESTAURANT_CLOSED");
    }
    if requestedItems.length() == 0 {
        return rejectedOrder("EMPTY_ORDER");
    }
    KitchenOrderItem[] pricedItems = [];
    decimal total = 0;
    // we use this to stop the same item being requested twice in one order.
    string[] seenItemIds = [];

    // requestedItem comes from the order, while menuItem comes from MongoDB.
    foreach OrderItemRequest requestedItem in requestedItems {
        if requestedItem.quantity <= 0 {
            return rejectedOrder("INVALID_QUANTITY");
        }
        foreach string seenItemId in seenItemIds {
            if seenItemId == requestedItem.itemId {
                return rejectedOrder("DUPLICATE_ITEM");
            }
        }
        seenItemIds.push(requestedItem.itemId);

        boolean itemFound = false;
        foreach MenuItem menuItem in restaurant.menu {
            if menuItem.itemId != requestedItem.itemId {
                continue;
            }
            itemFound = true;
            if !menuItem.available {
                return rejectedOrder("ITEM_UNAVAILABLE: " + requestedItem.itemId);
            }
            if menuItem.stock < requestedItem.quantity {
                return rejectedOrder("OUT_OF_STOCK: " + requestedItem.itemId);
            }
            // this record is the priced item we can pass to the next service.
            pricedItems.push({
                itemId: menuItem.itemId,
                name: menuItem.name,
                quantity: requestedItem.quantity,
                unitPrice: menuItem.price
            });
            total += menuItem.price * requestedItem.quantity;
            break;
        }
        if !itemFound {
            return rejectedOrder("ITEM_NOT_FOUND: " + requestedItem.itemId);
        }
    }

    // if we reach here, every item passed, so we return the final priced order data.
    return {
        accepted: true,
        reason: "",
        items: pricedItems,
        total: total,
        currency: "NAD"
    };
}

function rejectedOrder(string reason) returns OrderValidationResult {
    // rejected orders do not send any priced items or a usable total.
    return {
        accepted: false,
        reason: reason,
        items: [],
        total: 0,
        currency: "NAD"
    };
}

// a restaurant is open from its opening time up to, but not including, its closing time.
// overnight hours are not supported, so a restaurant that opens at 10 PM and closes at 2 AM is considered closed at 1 AM.
// we dont got those typa resturants out here yk
# Checks whether the current local restaurant time falls within today's opening window.
# + openingHours - The restaurant's weekly opening schedule.
# + return - Whether the restaurant is open now.
public function isOpenNow(OpeningHours[] openingHours) returns boolean {
    time:TimeZone|error zoneResult = new (restaurantTimeZone);
    if zoneResult is error {
        return false;
    }
    time:TimeZone restaurantZone = zoneResult;
    time:Civil currentTime = restaurantZone.utcToCivil(time:utcNow());
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

# Validates clock strings and rejects duplicate weekdays in an opening-hours schedule.
# + openingHours - The schedule to validate.
# + return - An error when a time or weekday is invalid.
public function validateOpeningHours(OpeningHours[] openingHours) returns error? {
    Day[] seenDays = [];
    foreach OpeningHours hours in openingHours {
        if !isValidClockTime(hours.open) || !isValidClockTime(hours.close) {
            return error("Opening and closing times must use HH:mm in 24-hour time");
        }
        if hours.open >= hours.close {
            return error("Opening time must be earlier than closing time");
        }
        foreach Day seenDay in seenDays {
            if seenDay == hours.day {
                return error("Opening hours may only contain one entry per day");
            }
        }
        seenDays.push(hours.day);
    }
}

function isValidClockTime(string value) returns boolean {
    if value.length() != 5 || value.substring(2, 3) != ":" {
        return false;
    }
    string digits = value.substring(0, 2) + value.substring(3, 5);
    foreach int index in 0 ..< digits.length() {
        string digit = digits.substring(index, index + 1);
        if digit < "0" || digit > "9" {
            return false;
        }
    }
    string hour = value.substring(0, 2);
    string minute = value.substring(3, 5);
    return hour >= "00" && hour <= "23" && minute >= "00" && minute <= "59";
}

# Allows only the restaurant's valid next kitchen status.
# + currentStatus - The current kitchen order status.
# + nextStatus - The requested restaurant status.
# + return - Whether the requested transition is allowed.
public function isValidKitchenTransition(KitchenOrderStatus currentStatus, RestaurantStatus nextStatus) returns boolean {
    if currentStatus == "CONFIRMED" {
        return nextStatus == "PREPARING" || nextStatus == "REJECTED";
    }
    if currentStatus == "PREPARING" {
        return nextStatus == "READY";
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
