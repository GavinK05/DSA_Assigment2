import ballerina/http;

configurable int port = 8082;
configurable string kafkaBootstrap = "localhost:9092";
configurable string mongoUrl = "mongodb://localhost:27017";

listener http:Listener httpListener = new (port);
