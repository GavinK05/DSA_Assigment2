# Kafka address, set in Config.toml.
configurable string kafkaBootstrap = ?;
# MongoDB connection string, set in Config.toml.
configurable string mongoUrl = ?;
# HTTP port for the Order Service (defaults to 8083 if Config.toml doesn't set it).
configurable int port = 8083;
