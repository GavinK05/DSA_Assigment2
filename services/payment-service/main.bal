import ballerina/http;

configurable string kafkaBootstrap = ?;
configurable string mongoUrl = ?;
configurable int port = ?;

listener http:Listener paymentListener = new (port);