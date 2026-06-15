package com.univates.fishing_backend.repository;

import com.univates.fishing_backend.entity.WaterBody;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WaterBodyRepository extends JpaRepository<WaterBody, Long>, WaterBodyRepositoryCustom {

    Optional<WaterBody> findByOsmId(Long osmId);

    @Query(
            value =
                    """
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
            CAST(
                (
                    SELECT COUNT(*)
                    FROM catch_record c
                    WHERE c.water_body_id = water_body.id
                ) AS bigint
            ) AS catch_count,
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
        """,
            nativeQuery = true)
    Optional<WaterBodyViewportRow> findNearest(
            @Param("lat") double lat, @Param("lon") double lon, @Param("radiusM") double radiusM);

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

        Long getCatchCount();

        java.time.Instant getCreatedAt();

        java.time.Instant getUpdatedAt();
    }
}
