package com.univates.fishing_backend.repository;

import com.univates.fishing_backend.entity.Establishment;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EstablishmentRepository extends JpaRepository<Establishment, Long> {

    Optional<Establishment> findByOsmId(Long osmId);

    /**
     * Busca combinável: filtra por nome (ILIKE), categoria e raio em torno de um ponto.
     * Todos os parâmetros são opcionais (null = sem filtro). Quando lat/lon são informados,
     * o resultado vem ordenado por distância (mais próximos primeiro) e {@code distanceMeters}
     * é preenchido; caso contrário ordena por nome. Os {@code CAST(... )} garantem que o
     * Postgres infira o tipo mesmo quando o parâmetro chega nulo.
     */
    @Query(
            value =
                    """
        SELECT
            id,
            name,
            category,
            address,
            phone,
            ST_X(geom) AS lon,
            ST_Y(geom) AS lat,
            CASE
                WHEN CAST(:lat AS double precision) IS NULL OR CAST(:lon AS double precision) IS NULL THEN NULL
                ELSE ST_Distance(
                    geom::geography,
                    ST_SetSRID(ST_MakePoint(CAST(:lon AS double precision), CAST(:lat AS double precision)), 4326)::geography
                )
            END AS distanceMeters,
            osm_id AS osmId,
            source,
            created_at AS createdAt,
            updated_at AS updatedAt
        FROM establishment
        WHERE (CAST(:q AS text) IS NULL OR name ILIKE '%' || CAST(:q AS text) || '%')
          AND (CAST(:category AS text) IS NULL OR category = CAST(:category AS text))
          AND (
                CAST(:lat AS double precision) IS NULL
                OR CAST(:lon AS double precision) IS NULL
                OR CAST(:radiusM AS double precision) IS NULL
                OR ST_DWithin(
                    geom::geography,
                    ST_SetSRID(ST_MakePoint(CAST(:lon AS double precision), CAST(:lat AS double precision)), 4326)::geography,
                    CAST(:radiusM AS double precision)
                )
          )
        ORDER BY
            CASE
                WHEN CAST(:lat AS double precision) IS NULL OR CAST(:lon AS double precision) IS NULL THEN NULL
                ELSE ST_Distance(
                    geom::geography,
                    ST_SetSRID(ST_MakePoint(CAST(:lon AS double precision), CAST(:lat AS double precision)), 4326)::geography
                )
            END ASC NULLS LAST,
            name ASC
        LIMIT CAST(:limit AS integer)
        """,
            nativeQuery = true)
    List<EstablishmentRow> search(
            @Param("q") String q,
            @Param("category") String category,
            @Param("lat") Double lat,
            @Param("lon") Double lon,
            @Param("radiusM") Double radiusM,
            @Param("limit") int limit);

    interface EstablishmentRow {
        Long getId();

        String getName();

        String getCategory();

        String getAddress();

        String getPhone();

        Double getLon();

        Double getLat();

        Double getDistanceMeters();

        Long getOsmId();

        String getSource();

        Instant getCreatedAt();

        Instant getUpdatedAt();
    }
}
