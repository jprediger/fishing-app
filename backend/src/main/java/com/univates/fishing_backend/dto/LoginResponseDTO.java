package com.univates.fishing_backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record LoginResponseDTO(
        @Schema(description = "JWT token (Bearer)") String token,
        @Schema(description = "Token type", example = "Bearer") String tokenType,
        @Schema(description = "Token lifetime in seconds", example = "604800") long expiresIn,
        @Schema(description = "Authenticated user") UserResponseDTO user) {

    public static LoginResponseDTO bearer(String token, long expiresIn, UserResponseDTO user) {
        return new LoginResponseDTO(token, "Bearer", expiresIn, user);
    }
}
