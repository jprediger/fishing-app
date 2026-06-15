package com.univates.fishing_backend.repository;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
class WaterBodyRepositoryImpl implements WaterBodyRepositoryCustom {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    @Override
    public List<WaterBodyRepository.WaterBodyViewportRow> findInBbox(
            double minLon, double minLat, double maxLon, double maxLat, Double simplifyTolerance, int maxFeatures) {
        String sql =
                """
                SELECT
                    id,
                    name,
                    water_type AS waterType,
                    ST_AsGeoJSON(
                        CASE
                            WHEN :simplifyTolerance IS NULL OR :simplifyTolerance = 0 THEN geom
                            ELSE ST_SimplifyPreserveTopology(geom, :simplifyTolerance)
                        END
                    ) AS geomGeoJson,
                    osm_id AS osmId,
                    source,
                    ST_X(ST_Centroid(geom)) AS centerLon,
                    ST_Y(ST_Centroid(geom)) AS centerLat,
                    CAST(NULL AS double precision) AS distanceMeters,
                    COALESCE(
                        (
                            SELECT COUNT(*)
                            FROM catch_record c
                            WHERE c.water_body_id = water_body.id
                        ),
                        0
                    ) AS catch_count,
                    created_at AS createdAt,
                    updated_at AS updatedAt
                FROM water_body
                WHERE ST_Intersects(
                    geom,
                    ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)
                )
                ORDER BY id
                LIMIT :maxFeatures
                """;

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("minLon", minLon)
                .addValue("minLat", minLat)
                .addValue("maxLon", maxLon)
                .addValue("maxLat", maxLat)
                .addValue("simplifyTolerance", simplifyTolerance)
                .addValue("maxFeatures", maxFeatures);

        return jdbcTemplate.query(
                sql,
                params,
                (rs, rowNum) -> new WaterBodyRow(
                        rs.getLong("id"),
                        rs.getString("name"),
                        rs.getString("waterType"),
                        rs.getString("geomGeoJson"),
                        rs.getObject("osmId", Long.class),
                        rs.getString("source"),
                        rs.getObject("centerLon", Double.class),
                        rs.getObject("centerLat", Double.class),
                        rs.getObject("distanceMeters", Double.class),
                        rs.getObject("catch_count", Long.class),
                        rs.getTimestamp("createdAt") == null
                                ? null
                                : rs.getTimestamp("createdAt").toInstant(),
                        rs.getTimestamp("updatedAt") == null
                                ? null
                                : rs.getTimestamp("updatedAt").toInstant()));
    }

    private record WaterBodyRow(
            Long id,
            String name,
            String waterType,
            String geomGeoJson,
            Long osmId,
            String source,
            Double centerLon,
            Double centerLat,
            Double distanceMeters,
            Long catchCount,
            java.time.Instant createdAt,
            java.time.Instant updatedAt)
            implements WaterBodyRepository.WaterBodyViewportRow {

        @Override
        public Long getId() {
            return id;
        }

        @Override
        public String getName() {
            return name;
        }

        @Override
        public String getWaterType() {
            return waterType;
        }

        @Override
        public String getGeomGeoJson() {
            return geomGeoJson;
        }

        @Override
        public Long getOsmId() {
            return osmId;
        }

        @Override
        public String getSource() {
            return source;
        }

        @Override
        public Double getCenterLon() {
            return centerLon;
        }

        @Override
        public Double getCenterLat() {
            return centerLat;
        }

        @Override
        public Double getDistanceMeters() {
            return distanceMeters;
        }

        @Override
        public Long getCatchCount() {
            return catchCount;
        }

        @Override
        public java.time.Instant getCreatedAt() {
            return createdAt;
        }

        @Override
        public java.time.Instant getUpdatedAt() {
            return updatedAt;
        }
    }
}
