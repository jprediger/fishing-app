package com.univates.fishing_backend.repository;

import com.univates.fishing_backend.entity.WaterBody;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

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
            ST_AsGeoJSON(geom) AS geomGeoJson,
            osm_id AS osmId,
            source,
            ST_X(ST_Centroid(geom)) AS centerLon,
            ST_Y(ST_Centroid(geom)) AS centerLat,
            created_at AS createdAt,
            updated_at AS updatedAt
        FROM water_body
        WHERE ST_Intersects(
            geom,
            ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)
        )
        ORDER BY id
        """, nativeQuery = true)
    List<WaterBodyViewportRow> findInBbox(
        double minLon,
        double minLat,
        double maxLon,
        double maxLat
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

        OffsetDateTime getCreatedAt();

        OffsetDateTime getUpdatedAt();
    }
}
