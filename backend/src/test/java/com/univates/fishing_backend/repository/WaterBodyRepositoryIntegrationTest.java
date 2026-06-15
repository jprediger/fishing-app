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
class WaterBodyRepositoryIntegrationTest {

    @Autowired
    private WaterBodyRepository waterBodyRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanTable() {
        jdbcTemplate.update("DELETE FROM catch_photo");
        jdbcTemplate.update("DELETE FROM catch_record");
        jdbcTemplate.update("DELETE FROM water_body");
        jdbcTemplate.update("DELETE FROM fish");
        jdbcTemplate.update("DELETE FROM users");
    }

    @Test
    void findNearest_returnsClosestWaterBodyInsideRadius() {
        insertWaterBody(1L, "Rio A", "RIVER", "LINESTRING(-51.30 -30.10, -51.20 -30.08)", 1001L);
        insertWaterBody(2L, "Rio B", "RIVER", "LINESTRING(-52.10 -31.10, -52.00 -31.00)", 1002L);

        var result = waterBodyRepository.findNearest(-30.085, -51.235, 5_000d);

        assertThat(result).isPresent();
        assertThat(result.orElseThrow().getName()).isEqualTo("Rio A");
        assertThat(result.orElseThrow().getDistanceMeters()).isNotNull();
        assertThat(result.orElseThrow().getDistanceMeters()).isGreaterThan(0d);
    }

    @Test
    void findNearest_returnsEmptyOutsideRadius() {
        insertWaterBody(1L, "Rio A", "RIVER", "LINESTRING(-51.30 -30.10, -51.20 -30.08)", 1001L);

        var result = waterBodyRepository.findNearest(-32.0, -54.0, 500d);

        assertThat(result).isEmpty();
    }

    @Test
    void findInBbox_returnsBodiesInsideViewport() {
        insertUser(1L);
        insertFish(1L);
        insertWaterBody(1L, "Rio A", "RIVER", "LINESTRING(-51.30 -30.10, -51.20 -30.08)", 1001L);
        insertWaterBody(
                2L,
                "Lago B",
                "LAKE",
                "POLYGON((-51.10 -30.20, -51.00 -30.20, -51.00 -30.10, -51.10 -30.10, -51.10 -30.20))",
                1002L);
        insertCatch(1L, 1L);
        insertCatch(2L, 1L);
        insertCatch(3L, 2L);

        var result = waterBodyRepository.findInBbox(-51.40, -30.30, -50.90, -30.00, 0.01, 500);

        assertThat(result).hasSize(2);
        assertThat(result.getFirst().getGeomGeoJson()).contains("\"type\"");
        assertThat(result.getFirst().getCatchCount()).isEqualTo(2L);
        assertThat(result.get(1).getCatchCount()).isEqualTo(1L);
    }

    private void insertWaterBody(long id, String name, String waterType, String wkt, long osmId) {
        jdbcTemplate.update(
                """
            INSERT INTO water_body (id, name, water_type, geom, osm_id, source, created_at, updated_at)
            VALUES (?, ?, ?, ST_GeomFromText(?, 4326), ?, 'OSM', now(), now())
            """,
                id,
                name,
                waterType,
                wkt,
                osmId);
    }

    private void insertCatch(long id, long waterBodyId) {
        jdbcTemplate.update(
                """
            INSERT INTO catch_record (id, user_id, water_body_id, location, location_visibility,
                                      species_id, fishing_method, purpose, caught_at, created_at)
            VALUES (?, 1, ?, ST_GeomFromText('POINT(-51.0 -30.0)', 4326), 'EXACT',
                    1, 'ARREMESSO', 'SPORT', now(), now())
            """,
                id,
                waterBodyId);
    }

    private void insertUser(long id) {
        jdbcTemplate.update(
                """
            INSERT INTO users (id, name, email, password, role, active, created_at, updated_at)
            VALUES (?, 'Demo', 'demo@fishing.local', 'hash', 'USER', TRUE, now(), now())
            ON CONFLICT (id) DO NOTHING
            """,
                id);
    }

    private void insertFish(long id) {
        jdbcTemplate.update(
                """
            INSERT INTO fish (id, name, description, region, type, icon_path, created_at, updated_at)
            VALUES (?, 'Tucunaré', 'desc', 'RS', 'FRESHWATER', NULL, now(), now())
            ON CONFLICT (id) DO NOTHING
            """,
                id);
    }
}
