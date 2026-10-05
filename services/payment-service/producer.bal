import ballerinax/kafka;
import ballerina/time;
import ballerina/uuid;

kafka:ProducerConfiguration producerConfig = {
    clientId: "payment-service",
    acks: "all"
};

final kafka:Producer paymentProducer =
    check new (kafkaBootstrap, producerConfig);

function publishPaymentCompleted(Payment payment) returns error? {

    PaymentCompletedData eventData = {
        paymentId: payment.paymentId,
        customerId: payment.customerId,
        amount: payment.amount,
        currency: payment.currency,
        method: payment.method
    };

    EventEnvelope event = {
        eventId: "EVT-" + uuid:createType4AsString(),
        eventType: "payments.completed",
        version: 1,
        occurredAt: time:utcToString(time:utcNow()),
        'source: "payment-service",
        orderId: payment.orderId,
        data: eventData
    };

    check paymentProducer->send({
        topic: "payments.completed",
        key: payment.orderId,
        value: event
    });
}

function publishPaymentFailed(Payment payment) returns error? {

    PaymentFailedData eventData = {
        paymentId: payment.paymentId,
        customerId: payment.customerId,
        amount: payment.amount,
        reason: payment.reason
    };

    EventEnvelope event = {
        eventId: "EVT-" + uuid:createType4AsString(),
        eventType: "payments.failed",
        version: 1,
        occurredAt: time:utcToString(time:utcNow()),
        'source: "payment-service",
        orderId: payment.orderId,
        data: eventData
    };

    check paymentProducer->send({
        topic: "payments.failed",
        key: payment.orderId,
        value: event
    });
}