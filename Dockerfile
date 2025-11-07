FROM eclipse-temurin:25-jre
WORKDIR /app
# Copy the built JAR from Maven target/
COPY target/spring-petclinic-*.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]