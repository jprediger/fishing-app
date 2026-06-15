package com.univates.fishing_backend.dto;

import com.univates.fishing_backend.entity.WaterType;
import java.time.OffsetDateTime;
import tools.jackson.databind.JsonNode;

public record WaterBodyResponseDTO(
        Long id,
        String name,
        WaterType waterType,
        JsonNode geometry,
        Long osmId,
        String source,
        Double centerLon,
        Double centerLat,
        Double distanceMeters,
        Long catchCount,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt) {}
