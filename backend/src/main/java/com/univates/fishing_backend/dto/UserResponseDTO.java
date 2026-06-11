package com.univates.fishing_backend.dto;

import java.time.OffsetDateTime;

public record UserResponseDTO(
    Long id,
    String name,
    String email,
    Boolean active,
    OffsetDateTime createdAt,
    OffsetDateTime updatedAt
) {}
