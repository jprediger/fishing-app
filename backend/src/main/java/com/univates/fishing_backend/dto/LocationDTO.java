package com.univates.fishing_backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

public record LocationDTO(
        @Schema(description = "Latitude", example = "-30.05") @NotNull(message = "Latitude is required") Double lat,
        @Schema(description = "Longitude", example = "-51.23") @NotNull(message = "Longitude is required")
                Double lon) {}
