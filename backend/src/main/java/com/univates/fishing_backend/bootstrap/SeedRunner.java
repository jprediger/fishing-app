package com.univates.fishing_backend.bootstrap;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import java.util.Comparator;
import java.util.List;

/**
 * Executa todos os {@link DataSeeder} registrados, ordenados por {@code order()},
 * uma vez na inicialização da aplicação.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SeedRunner implements ApplicationRunner {

    private final List<DataSeeder> seeders;

    @Override
    public void run(ApplicationArguments args) {
        seeders.stream()
            .sorted(Comparator.comparingInt(DataSeeder::order))
            .forEach(seeder -> {
                log.info("Seed: executando {}", seeder.getClass().getSimpleName());
                seeder.run();
            });
    }
}
