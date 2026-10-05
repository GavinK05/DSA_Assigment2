FROM eclipse-temurin:21-jre

WORKDIR /app

COPY target/bin/customer_service.jar /app/customer_service.jar
COPY Config.docker.toml /app/Config.docker.toml

ENV BAL_CONFIG_FILES=/app/Config.docker.toml

EXPOSE 8081

CMD ["java", "-jar", "/app/customer_service.jar"]
