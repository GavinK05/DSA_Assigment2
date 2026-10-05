FROM eclipse-temurin:21-jre

WORKDIR /app

COPY target/bin/notification_service.jar /app/notification_service.jar
COPY Config.docker.toml /app/Config.docker.toml

ENV BAL_CONFIG_FILES=/app/Config.docker.toml

EXPOSE 8086

CMD ["java", "-jar", "/app/notification_service.jar"]
