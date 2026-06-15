package com.univates.fishing_backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.univates.fishing_backend.entity.FishingMethod;
import com.univates.fishing_backend.entity.FishingPurpose;
import com.univates.fishing_backend.entity.LocationVisibility;
import java.time.OffsetDateTime;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record CatchResponseDTO(
        Long id,
        FishResponseDTO species,
        WaterBodyResponseDTO waterBody,
        LocationDTO location,
        LocationVisibility locationVisibility,
        Integer weightGrams,
        Integer lengthMm,
        String description,
        FishingMethod fishingMethod,
        FishingPurpose purpose,
        OffsetDateTime caughtAt,
        WeatherDTO weather,
        boolean mine,
        List<CatchPhotoResponseDTO> photos,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt) {}
