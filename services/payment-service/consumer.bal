import ballerinax/kafka;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

kafka:ConsumerConfiguration consumerConfig = {
    groupId: "payment-service",
    topics: ["restaurant.order-validated"],
    offsetReset: "earliest",
    pollingInterval: 1,
    autoCommit: false
};

listener kafka:Listener paymentKafkaListener =
    new (kafkaBootstrap, consumerConfig);

service on paymentKafkaListener {

    remote function onConsumerRecord(
        kafka:Caller caller,
        kafka:BytesConsumerRecord[] records
    ) returns error? {

        foreach kafka:BytesConsumerRecord consumerRecord in records {

            string rawEvent = check string:fromBytes(consumerRecord.value);
            json eventJson = check rawEvent.fromJsonString();
            EventEnvelope event = check eventJson.cloneWithType();

            check handleOrderValidated(event);
        }

        check caller->commit();
    }
}  

function handleOrderValidated(EventEnvelope event) returns error? {

    if check hasProcessedEvent(event.eventId) {
        log:printInfo("Skipping already processed event: " + event.eventId);
        return;
    }

    Payment? existingPayment = check findPaymentByOrder(event.orderId);

    if existingPayment is Payment {
        log:printInfo(
            "Payment already exists for order: " + event.orderId
        );
        return;
    }

    OrderValidatedData orderData =
        check event.data.cloneWithType();

    if !orderData.accepted {
        log:printInfo(
            "Skipping payment because restaurant rejected order: "
            + event.orderId
        );

        check saveProcessedEvent({
            eventId: event.eventId,
            processedAt: time:utcToString(time:utcNow())
        });

        return;
    }

    PaymentDecision decision = simulateCharge(orderData);

    string now = time:utcToString(time:utcNow());

    Payment payment = {
        paymentId: "PAY-" + uuid:createType4AsString(),
        orderId: event.orderId,
        customerId: orderData.customerId,
        amount: orderData.total,
        currency: orderData.currency,
        method: "CARD",
        status: decision.status,
        reason: decision.reason,
        processedAt: now
    };

    check insertPayment(payment);

    if payment.status == SUCCESS {
        check publishPaymentCompleted(payment);
    } else {
        check publishPaymentFailed(payment);
    }

    check saveProcessedEvent({
        eventId: event.eventId,
        processedAt: now
    });
}