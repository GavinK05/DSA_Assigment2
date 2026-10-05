import ballerina/time;
import ballerina/uuid;

// Business rules for customers and addresses. Errors carry a short code in message().

# Validates a registration request and stores a new customer.
# + request - Registration data from the request body.
# + return - The created customer, or an error (INVALID_REQUEST:..., DUPLICATE).
public function registerCustomer(CustomerCreateRequest request) returns Customer|error {
    string name = request.name.trim();
    string email = request.email.trim().toLowerAscii();
    string phone = request.phone.trim();
    if name == "" {
        return error("INVALID_REQUEST:name is required");
    }
    if !isValidEmail(email) {
        return error("INVALID_REQUEST:a valid email is required");
    }
    if phone == "" {
        return error("INVALID_REQUEST:phone is required");
    }

    Customer|error existing = findCustomerByEmail(email);
    if existing is Customer {
        return error("DUPLICATE");
    }
    if existing.message() != "NOT_FOUND" {
        return existing;
    }

    Customer customer = {
        customerId: "CUS-" + uuid:createType4AsString(),
        name: name,
        email: email,
        phone: phone,
        addresses: [],
        createdAt: time:utcToString(time:utcNow())
    };
    return insertCustomer(customer);
}

# Validates and applies a name/phone update.
# + customerId - Customer to update.
# + request - Fields to change; at least one is required.
# + return - The updated customer, or an error.
public function changeCustomer(string customerId, CustomerUpdateRequest request) returns Customer|error {
    string? name = request?.name;
    string? phone = request?.phone;
    if name is () && phone is () {
        return error("INVALID_REQUEST:provide name or phone");
    }
    if name is string && name.trim() == "" {
        return error("INVALID_REQUEST:name cannot be empty");
    }
    if phone is string && phone.trim() == "" {
        return error("INVALID_REQUEST:phone cannot be empty");
    }
    return updateCustomer(customerId, name is string ? name.trim() : (), phone is string ? phone.trim() : ());
}

# Validates an address and attaches it to a customer.
# + customerId - Customer that owns the address.
# + request - Address data from the request body.
# + return - The new address, or an error.
public function createAddress(string customerId, AddressRequest request) returns Address|error {
    if request.label.trim() == "" || request.street.trim() == "" || request.suburb.trim() == "" || request.city.trim() == "" {
        return error("INVALID_REQUEST:label, street, suburb and city are required");
    }
    if request.lat < -90d || request.lat > 90d || request.lng < -180d || request.lng > 180d {
        return error("INVALID_REQUEST:lat must be -90..90 and lng must be -180..180");
    }
    Address address = {
        addressId: "ADR-" + uuid:createType4AsString(),
        label: request.label.trim(),
        street: request.street.trim(),
        suburb: request.suburb.trim(),
        city: request.city.trim(),
        lat: request.lat,
        lng: request.lng
    };
    check addAddress(customerId, address);
    return address;
}

function isValidEmail(string email) returns boolean {
    int? at = email.indexOf("@");
    if at is () || at < 1 {
        return false;
    }
    string domain = email.substring(at + 1);
    return domain.includes(".") && !domain.startsWith(".") && !domain.endsWith(".") && !email.includes(" ");
}
