package com.univates.fishing_backend.dto;

import com.univates.fishing_backend.entity.FishType;
import java.time.OffsetDateTime;

public record FishResponseDTO(
        Long id,
        String name,
        String description,
        String region,
        FishType type,
        IconDTO icon,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt) {}
