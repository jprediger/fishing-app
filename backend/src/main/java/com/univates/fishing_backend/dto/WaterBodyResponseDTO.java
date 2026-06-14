package com.univates.fishing_backend.dto;

import com.univates.fishing_backend.entity.WaterType;
import tools.jackson.databind.JsonNode;

import java.time.OffsetDateTime;

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
    OffsetDateTime createdAt,
    OffsetDateTime updatedAt
) {}
