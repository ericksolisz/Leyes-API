# ---- Build stage: JDK + Maven wrapper, compiles the application ----
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

# Copy only what is needed to resolve dependencies first, so this layer is
# cached until the pom.xml or the Maven wrapper change.
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw -B -q dependency:go-offline

# Source changes only invalidate the layers from here on.
COPY src src
RUN ./mvnw -B -q package -DskipTests

# ---- Runtime stage: JRE only, plus the packaged jar ----
FROM eclipse-temurin:21-jre
WORKDIR /app

# Do not run as root inside the container.
RUN useradd --system --no-create-home app
USER app

COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
