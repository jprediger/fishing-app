package com.univates.fishing_backend.dto;

import com.univates.fishing_backend.entity.Role;
import com.univates.fishing_backend.entity.User;

import java.time.OffsetDateTime;

public record UserResponseDTO(
    Long id,
    String name,
    String email,
    Role role,
    Boolean active,
    OffsetDateTime createdAt,
    OffsetDateTime updatedAt
) {
    public static UserResponseDTO from(User user) {
        return new UserResponseDTO(
            user.getId(),
            user.getName(),
            user.getEmail(),
            user.getRole(),
            user.getActive(),
            user.getCreatedAt(),
            user.getUpdatedAt()
        );
    }
}
