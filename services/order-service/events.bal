# Wraps every Kafka message on every topic with a common envelope. This is useful for event sourcing and event-driven architectures. 
public type EventEnvelope record {| 
    string eventId; 
    string eventType;
    int version;
    string occurredAt; 
    string 'source ;
    string orderId; 
    json data; 
|};