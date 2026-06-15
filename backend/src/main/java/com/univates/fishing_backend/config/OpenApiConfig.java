package com.univates.fishing_backend.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI fishingBackendOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Fishing Backend API")
                        .description("API REST do aplicativo de pesca (Univates).")
                        .version("0.0.1-SNAPSHOT")
                        .contact(new Contact().name("Univates").email("admin@univates.br"))
                        .license(new License().name("MIT")));
    }
}
