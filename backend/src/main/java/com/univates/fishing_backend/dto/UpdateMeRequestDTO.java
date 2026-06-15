package com.univates.fishing_backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateMeRequestDTO(
        @Schema(description = "User name", example = "João Prediger") @NotBlank(message = "Name is required")
                String name,
        @Schema(description = "New password (optional; if blank keeps the current one)", example = "newStrongPass123")
                @Size(min = 8, message = "Password must be at least 8 characters")
                String password) {}
