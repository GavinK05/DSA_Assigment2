import ballerina/hhtp;
import ballerina/log;

configurable string kafkaBootstrap = ?;
configurable string mongoUrl = ?;
configurable int port = 8085;

const string SERVICE_NAME = "delivery-service";
const string DB_NAME = "delivery-db";

listener http:Listener httpListener = new(port);

function init() returns error? {
    check ensureIndexes();
    log:printInfo("delivery-service started", port = port, kafka = kafkaBootstrap);
}