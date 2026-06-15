package com.univates.fishing_backend.repository;

import com.univates.fishing_backend.entity.CatchRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CatchRepository extends JpaRepository<CatchRecord, Long> {

    Page<CatchRecord> findByUser_Email(String email, Pageable pageable);

    Page<CatchRecord> findByUser_Id(Long userId, Pageable pageable);

    Page<CatchRecord> findBySpecies_Id(Long speciesId, Pageable pageable);

    Page<CatchRecord> findByWaterBody_Id(Long waterBodyId, Pageable pageable);

    Page<CatchRecord> findByUser_EmailAndSpecies_Id(String email, Long speciesId, Pageable pageable);

    long countByUser_Id(Long userId);

    @Query("select count(distinct c.species.id) from CatchRecord c where c.user.id = :userId")
    long countDistinctSpeciesByUser_Id(@Param("userId") Long userId);

    @Query("select count(distinct c.waterBody.id) from CatchRecord c where c.user.id = :userId")
    long countDistinctWaterBodyByUser_Id(@Param("userId") Long userId);

    @Query(
            value =
                    """
        SELECT *
        FROM catch_record
        WHERE ST_Intersects(
            location,
            ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)
        )
          AND (:speciesId IS NULL OR species_id = :speciesId)
        ORDER BY id
        """,
            countQuery =
                    """
        SELECT COUNT(*)
        FROM catch_record
        WHERE ST_Intersects(
            location,
            ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)
        )
          AND (:speciesId IS NULL OR species_id = :speciesId)
        """,
            nativeQuery = true)
    Page<CatchRecord> findAllInBbox(
            @Param("minLon") double minLon,
            @Param("minLat") double minLat,
            @Param("maxLon") double maxLon,
            @Param("maxLat") double maxLat,
            @Param("speciesId") Long speciesId,
            Pageable pageable);
}
