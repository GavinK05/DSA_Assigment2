import ballerinax/kafka;

kafka:ConsumerConfiguration consumerConfig = {
    groupId: "notification-service",
    topics: [
        "orders.created",
        "orders.status-changed",
        "restaurant.order-updated",
        "restaurant.order-validated",
        "payments.completed",
        "payments.failed",
        "delivery.assigned",
        "delivery.picked-up",
        "delivery.completed"
    ],
    offsetReset: "earliest",
    pollingInterval: 1,
    autoCommit: false
};

listener kafka:Listener notificationKafkaListener =
    new (kafkaBootstrap, consumerConfig);

service on notificationKafkaListener {

    remote function onConsumerRecord(
        kafka:Caller caller,
        kafka:BytesConsumerRecord[] records
    ) returns error? {

        foreach kafka:BytesConsumerRecord consumerRecord in records {

            string rawEvent =
                check string:fromBytes(consumerRecord.value);

            json eventJson =
                check rawEvent.fromJsonString();

            EventEnvelope event =
                check eventJson.cloneWithType();

            check handleNotificationEvent(event);
        }

        check caller->commit();
    }
}