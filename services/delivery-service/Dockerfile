# Build first on your machine: bal build  ->  target/bin/delivery_service.jar
FROM eclipse-temurin:21-jre

WORKDIR /app
COPY target/bin/delivery_service.jar /app/delivery_service.jar
COPY Config.docker.toml /app/Config.docker.toml

ENV BAL_CONFIG_FILES=/app/Config.docker.toml
EXPOSE 8085

CMD ["java", "-jar", "/app/delivery_service.jar"]
