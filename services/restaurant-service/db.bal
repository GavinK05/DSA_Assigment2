// Temporary store until the MongoDB connector is added.
Restaurant[] restaurantStore = [];

public function insertRestaurant(Restaurant restaurant) returns Restaurant|error {
    foreach Restaurant existing in restaurantStore {
        if existing.name == restaurant.name && existing.address.city == restaurant.address.city {
            return error("DUPLICATE");
        }
    }

    restaurantStore.push(restaurant);
    return restaurant;
}

