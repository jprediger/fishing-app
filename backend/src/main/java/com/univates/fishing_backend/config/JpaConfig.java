package com.univates.fishing_backend.config;

import java.time.OffsetDateTime;
import java.util.Optional;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.auditing.DateTimeProvider;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@Configuration
@EnableJpaAuditing(dateTimeProviderRef = "auditingDateTimeProvider")
public class JpaConfig {

    /**
     * As entidades usam {@link OffsetDateTime} nos campos @CreatedDate/@LastModifiedDate.
     * O provider padrão entrega {@code LocalDateTime}, que o JPA não converte para
     * {@code OffsetDateTime}. Este bean fornece o tipo correto.
     */
    @Bean
    public DateTimeProvider auditingDateTimeProvider() {
        return () -> Optional.of(OffsetDateTime.now());
    }
}
