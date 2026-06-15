package com.univates.fishing_backend.repository;

import java.util.List;
import org.springframework.data.repository.query.Param;

public interface WaterBodyRepositoryCustom {

    List<WaterBodyRepository.WaterBodyViewportRow> findInBbox(
            @Param("minLon") double minLon,
            @Param("minLat") double minLat,
            @Param("maxLon") double maxLon,
            @Param("maxLat") double maxLat,
            @Param("simplifyTolerance") Double simplifyTolerance,
            @Param("maxFeatures") int maxFeatures);
}
