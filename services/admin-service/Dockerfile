FROM eclipse-temurin:21-jre

WORKDIR /app

COPY target/bin/admin_service.jar /app/admin_service.jar
COPY Config.docker.toml /app/Config.docker.toml

ENV BAL_CONFIG_FILES=/app/Config.docker.toml

EXPOSE 8087

CMD ["java", "-jar", "/app/admin_service.jar"]
