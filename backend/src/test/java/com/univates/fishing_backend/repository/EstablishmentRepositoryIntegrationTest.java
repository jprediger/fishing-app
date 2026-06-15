package com.univates.fishing_backend.repository;

import static org.assertj.core.api.Assertions.assertThat;

import com.univates.fishing_backend.config.TestcontainersConfiguration;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
@TestPropertySource(properties = {"spring.flyway.enabled=true", "spring.jpa.hibernate.ddl-auto=validate"})
class EstablishmentRepositoryIntegrationTest {

    @Autowired
    private EstablishmentRepository establishmentRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanTable() {
        jdbcTemplate.update("DELETE FROM establishment");
    }

    @Test
    void search_byProximity_ordersByDistanceAndFillsDistance() {
        insert(1L, "Loja Perto", "LOJA_PESCA", -51.230, -30.085, 2001L);
        insert(2L, "Loja Longe", "LOJA_PESCA", -52.000, -31.000, 2002L);

        var result = establishmentRepository.search(null, null, -30.085, -51.230, 200_000d, 100);

        assertThat(result).hasSize(2);
        assertThat(result.getFirst().getName()).isEqualTo("Loja Perto");
        assertThat(result.getFirst().getDistanceMeters()).isNotNull();
        assertThat(result.get(0).getDistanceMeters()).isLessThan(result.get(1).getDistanceMeters());
    }

    @Test
    void search_byRadius_excludesOutsidePoints() {
        insert(1L, "Loja Perto", "LOJA_PESCA", -51.230, -30.085, 2001L);
        insert(2L, "Loja Longe", "LOJA_PESCA", -52.000, -31.000, 2002L);

        var result = establishmentRepository.search(null, null, -30.085, -51.230, 1_000d, 100);

        assertThat(result).hasSize(1);
        assertThat(result.getFirst().getName()).isEqualTo("Loja Perto");
    }

    @Test
    void search_byNameAndCategory_filters() {
        insert(1L, "Pesqueiro Sol", "PESQUEIRO", -51.230, -30.085, 2001L);
        insert(2L, "Loja do Rio", "LOJA_PESCA", -51.231, -30.086, 2002L);

        var byName = establishmentRepository.search("rio", null, null, null, null, 100);
        assertThat(byName).hasSize(1);
        assertThat(byName.getFirst().getName()).isEqualTo("Loja do Rio");
        assertThat(byName.getFirst().getDistanceMeters()).isNull();

        var byCategory = establishmentRepository.search(null, "PESQUEIRO", null, null, null, 100);
        assertThat(byCategory).hasSize(1);
        assertThat(byCategory.getFirst().getName()).isEqualTo("Pesqueiro Sol");
    }

    private void insert(long id, String name, String category, double lon, double lat, long osmId) {
        jdbcTemplate.update(
                """
            INSERT INTO establishment (id, name, category, geom, osm_id, source, created_at, updated_at)
            VALUES (?, ?, ?, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?, 'OSM', now(), now())
            """,
                id,
                name,
                category,
                lon,
                lat,
                osmId);
    }
}
