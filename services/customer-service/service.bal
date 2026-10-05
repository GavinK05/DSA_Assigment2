import ballerina/http;

type Address record {|
    string addressId;
    string street;
    string city;
    string houseNumber;
|};

type Customer record {|
    string customerId;
    string name;
    string email;
    string phone;
    Address[] addresses = [];
|};

Customer[] customers = [];

service /customers on new http:Listener(8081) {

    resource function post .(@http:Payload Customer customer) returns Customer {
        customers.push(customer);
        return customer;
    }

    resource function get .() returns Customer[] {
        return customers;
    }

    resource function get [string customerId]() returns Customer|http:NotFound {
        foreach Customer customer in customers {
            if customer.customerId == customerId {
                return customer;
            }
        }

        return http:NOT_FOUND;
    }

    resource function post [string customerId](
            @http:Payload Address newAddress)
            returns Address|http:NotFound {

        foreach int i in 0 ..< customers.length() {
            if customers[i].customerId == customerId {
                customers[i].addresses.push(newAddress);
                return newAddress;
            }
        }

        return http:NOT_FOUND;
    }
}