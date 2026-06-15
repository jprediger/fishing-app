package com.univates.fishing_backend.dto;

import java.time.OffsetDateTime;

public record CatchPhotoResponseDTO(
    Long id,
    String filePath,
    Integer position,
    OffsetDateTime createdAt
) {}
