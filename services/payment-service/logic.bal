import ballerina/lang.runtime;

function simulateCharge(OrderValidatedData orderData) returns PaymentDecision {

    runtime:sleep(1d);

    if orderData.total > 2000d {
        return {
            status: FAILED,
            reason: "AMOUNT_LIMIT_EXCEEDED"
        };
    }

    foreach PricedItem item in orderData.items {
        if item.name == "FAIL" {
            return {
                status: FAILED,
                reason: "CARD_DECLINED"
            };
        }
    }

    return {
        status: SUCCESS,
        reason: ""
    };
}