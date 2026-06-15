package com.univates.fishing_backend.dto;

import com.univates.fishing_backend.entity.Role;
import java.time.OffsetDateTime;

public record UserProfileDTO(
        Long id,
        String name,
        String avatarPath,
        Role role,
        OffsetDateTime memberSince,
        long catchCount,
        long speciesCount,
        long waterBodyCount) {}
