package com.univates.fishing_backend.migration;

import static org.assertj.core.api.Assertions.assertThat;

import com.univates.fishing_backend.config.TestcontainersConfiguration;
import com.univates.fishing_backend.entity.Fish;
import com.univates.fishing_backend.entity.FishType;
import com.univates.fishing_backend.repository.FishRepository;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;

/**
 * Verifica o seed V4__seed_fish_rs.sql (plano 0003). O contexto padrão de testes
 * desliga o Flyway (ddl-auto=create-drop); aqui ligamos o Flyway e validamos o
 * schema para que as migrations rodem de fato contra o Postgres do Testcontainers
 * -> estado pós-migration é exatamente o de produção.
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
@TestPropertySource(properties = {"spring.flyway.enabled=true", "spring.jpa.hibernate.ddl-auto=validate"})
class FishSeedIntegrationTest {

    @Autowired
    private FishRepository fishRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private static final List<String> EXPECTED_SPECIES = List.of(
            "Traíra",
            "Jundiá",
            "Dourado",
            "Grumatã",
            "Lambari",
            "Carpa",
            "Tilápia",
            "Black bass",
            "Cará",
            "Piava",
            "Cascudo",
            "Bagre",
            "Tainha",
            "Peixe-rei",
            "Linguado",
            "Corvina",
            "Robalo",
            "Enchova",
            "Pampo",
            "Papa-terra",
            "Pescada");

    @Test
    void seed_populatesAllRsSpecies() {
        List<String> names =
                fishRepository.findAll().stream().map(Fish::getName).toList();

        assertThat(names).containsAll(EXPECTED_SPECIES);
    }

    @Test
    void seed_everyFishHasRequiredFields() {
        List<Fish> seeded = fishRepository.findAll().stream()
                .filter(f -> EXPECTED_SPECIES.contains(f.getName()))
                .toList();

        assertThat(seeded).hasSize(EXPECTED_SPECIES.size());
        assertThat(seeded).allSatisfy(fish -> {
            assertThat(fish.getName()).isNotBlank();
            assertThat(fish.getType()).isIn((Object[]) FishType.values());
            assertThat(fish.getCreatedAt()).isNotNull();
        });
    }

    @Test
    void seed_isIdempotent_reapplyDoesNotDuplicate() {
        long before = fishRepository.count();

        // Reaplica o mesmo INSERT do seed -> ON CONFLICT (name) DO NOTHING.
        jdbcTemplate.update("INSERT INTO fish (name, description, region, type, created_at) VALUES "
                + "('Traíra', 'dup', 'RS', 'FRESHWATER', now()), "
                + "('Corvina', 'dup', 'RS', 'SALTWATER', now()) "
                + "ON CONFLICT (name) DO NOTHING");

        assertThat(fishRepository.count()).isEqualTo(before);
    }
}
