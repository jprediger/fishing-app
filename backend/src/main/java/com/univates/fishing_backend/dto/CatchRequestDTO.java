package com.univates.fishing_backend.dto;

import com.univates.fishing_backend.entity.FishingMethod;
import com.univates.fishing_backend.entity.FishingPurpose;
import com.univates.fishing_backend.entity.LocationVisibility;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.OffsetDateTime;

public record CatchRequestDTO(
        @Schema(description = "Water body id") @NotNull(message = "Water body is required") Long waterBodyId,
        @Schema(description = "Exact catch location") @NotNull(message = "Location is required") @Valid
                LocationDTO location,
        @Schema(description = "Public location visibility") @NotNull(message = "Location visibility is required")
                LocationVisibility locationVisibility,
        @Schema(description = "Species id") @NotNull(message = "Species is required") Long speciesId,
        @Min(value = 1, message = "Weight must be positive") Integer weightGrams,
        @Min(value = 1, message = "Length must be positive") Integer lengthMm,
        @Size(max = 5000, message = "Description is too long") String description,
        @NotNull(message = "Fishing method is required") FishingMethod fishingMethod,
        @NotNull(message = "Purpose is required") FishingPurpose purpose,
        @NotNull(message = "Caught at is required") OffsetDateTime caughtAt) {}
