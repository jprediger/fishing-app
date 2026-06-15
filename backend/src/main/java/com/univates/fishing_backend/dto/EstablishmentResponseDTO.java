package com.univates.fishing_backend.dto;

import com.univates.fishing_backend.entity.EstablishmentCategory;
import java.time.OffsetDateTime;

public record EstablishmentResponseDTO(
        Long id,
        String name,
        EstablishmentCategory category,
        String address,
        String phone,
        Double lon,
        Double lat,
        Double distanceMeters,
        Long osmId,
        String source,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt) {}
