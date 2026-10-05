FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/bin/order_service.jar /app/order_service.jar
COPY Config.docker.toml /app/Config.docker.toml
ENV BAL_CONFIG_FILES=/app/Config.docker.toml
EXPOSE 8083
CMD ["java", "-jar", "/app/order_service.jar"]