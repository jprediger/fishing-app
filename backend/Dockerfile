FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle .
RUN ./gradlew dependencies --no-daemon
COPY src src
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:21-jre
WORKDIR /app
# curl é usado pelo healthcheck do docker-compose.prod.yml (a imagem jre não o traz por padrão).
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
# Usuário não-root para reduzir a superfície de ataque do container.
RUN useradd --system --uid 1001 --no-create-home spring
COPY --from=builder /app/build/libs/*.jar app.jar
USER spring
EXPOSE 8080
# MaxRAMPercentage faz a JVM respeitar o limite de memória do container.
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
