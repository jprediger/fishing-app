package com.univates.fishing_backend.repository;

import com.univates.fishing_backend.entity.WaterBody;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

public interface WaterBodyRepository extends JpaRepository<WaterBody, Long> {

    Optional<WaterBody> findByOsmId(Long osmId);

    @Query(value = """
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
            created_at AS createdAt,
            updated_at AS updatedAt
        FROM water_body
        WHERE ST_Intersects(
            geom,
            ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)
        )
        ORDER BY id
        LIMIT :maxFeatures
        """, nativeQuery = true)
    List<WaterBodyViewportRow> findInBbox(
        @Param("minLon") double minLon,
        @Param("minLat") double minLat,
        @Param("maxLon") double maxLon,
        @Param("maxLat") double maxLat,
        @Param("simplifyTolerance") Double simplifyTolerance,
        @Param("maxFeatures") int maxFeatures
    );

    @Query(value = """
        SELECT
            id,
            name,
            water_type AS waterType,
            ST_AsGeoJSON(geom) AS geomGeoJson,
            osm_id AS osmId,
            source,
            ST_X(ST_Centroid(geom)) AS centerLon,
            ST_Y(ST_Centroid(geom)) AS centerLat,
            ST_Distance(
                geom::geography,
                ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
            ) AS distanceMeters,
            created_at AS createdAt,
            updated_at AS updatedAt
        FROM water_body
        WHERE ST_DWithin(
            geom::geography,
            ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
            :radiusM
        )
        ORDER BY geom::geography <-> ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
        LIMIT 1
        """, nativeQuery = true)
    Optional<WaterBodyViewportRow> findNearest(
        @Param("lat") double lat,
        @Param("lon") double lon,
        @Param("radiusM") double radiusM
    );

    interface WaterBodyViewportRow {
        Long getId();

        String getName();

        String getWaterType();

        String getGeomGeoJson();

        Long getOsmId();

        String getSource();

        Double getCenterLon();

        Double getCenterLat();

        Double getDistanceMeters();

        OffsetDateTime getCreatedAt();

        OffsetDateTime getUpdatedAt();
    }
}
