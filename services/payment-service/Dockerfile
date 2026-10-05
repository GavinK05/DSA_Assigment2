FROM eclipse-temurin:21-jre

WORKDIR /app

COPY target/bin/payment_service.jar /app/payment_service.jar
COPY Config.docker.toml /app/Config.docker.toml

ENV BAL_CONFIG_FILES=/app/Config.docker.toml

EXPOSE 8084

CMD ["java", "-jar", "/app/payment_service.jar"]
