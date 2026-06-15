package com.univates.fishing_backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterRequestDTO(
        @Schema(description = "User name", example = "João Prediger") @NotBlank(message = "Name is required")
                String name,
        @Schema(description = "E-mail (used as login)", example = "joao@univates.br")
                @NotBlank(message = "E-mail is required")
                @Email(message = "Invalid e-mail")
                String email,
        @Schema(description = "Password (min 8 characters)", example = "strongPass123")
                @NotBlank(message = "Password is required")
                @Size(min = 8, message = "Password must be at least 8 characters")
                String password) {}
