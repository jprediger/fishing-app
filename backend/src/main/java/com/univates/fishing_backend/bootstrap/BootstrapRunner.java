package com.univates.fishing_backend.bootstrap;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Bootstrap mínimo do app: garante ADMIN inicial no boot normal.
 *
 * <p>O comando {@code ./gradlew seed} desliga este runner e executa todos
 * os seeders de uma vez via {@link SeedRunner}.
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.bootstrap.enabled", havingValue = "true", matchIfMissing = true)
public class BootstrapRunner implements ApplicationRunner {

    private final AdminUserSeeder adminUserSeeder;

    @Override
    public void run(ApplicationArguments args) {
        log.info("Bootstrap: executando AdminUserSeeder");
        adminUserSeeder.run();
    }
}
