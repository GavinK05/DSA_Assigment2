FROM eclipse-temurin:21-jre

WORKDIR /app

COPY target/bin/restaurant_service.jar /app/restaurant_service.jar
COPY Config.docker.toml /app/Config.docker.toml

ENV BAL_CONFIG_FILES=/app/Config.docker.toml

EXPOSE 8082

CMD ["java", "-jar", "/app/restaurant_service.jar"]
