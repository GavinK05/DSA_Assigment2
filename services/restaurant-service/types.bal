//used enum so the values of the type are rstricted to the values in the enum
// kinda like what we did in assignment 1 with the grpc in propertyStatus
public enum Day {
    MONDAY,
    TUESDAY,
    WEDNESDAY,
    THURSDAY,
    FRIDAY,
    SATURDAY,
    SUNDAY
}

public enum KitchenOrderStatus {
    CONFIRMED,
    PREPARING,
    READY,
    REJECTED
}

// lat just shot for lattitude btw and lng is longitude cause them names too long
public type RestaurantAddress record {|
    string street;
    string suburb;
    string city;
    decimal lat;
    decimal lng;
|};

// Day uses the enum above (Day) to use one of the valid days so we dont get
// smth like wedenesday or smth
public type OpeningHours record {|
    Day day;
    string open;
    string close;
|};

public type MenuItem record {|
    string itemId;
    string name;
    string description;
    decimal price;
    int stock;
    boolean available;
|};

// ok quick explainer cause this lwk confusing
// so why address isnt a list also is cause we only use one record of the address cause a resturant only has one location mos
// but we can have many opening hours and menu items so those are lists
// also the id is a string cause we use uuid for the id so it can be a string and not an int
public type Restaurant record {|
    string restaurantId;
    string name;
    string cuisine;
    RestaurantAddress address;
    OpeningHours[] openingHours;
    MenuItem[] menu;
    string createdAt;
|};

public type KitchenOrderItem record {|
    string itemId;
    string name;
    int quantity;
    decimal unitPrice;
|};

// same thing as Resturant record  with many kitchen order items can be in one item
// but one status per kitchen order so its not a list
public type KitchenOrder record {|
    string orderId;
    string restaurantId;
    KitchenOrderItem[] items;
    decimal total;
    KitchenOrderStatus status;
    string receivedAt;
    string updatedAt;
|};
