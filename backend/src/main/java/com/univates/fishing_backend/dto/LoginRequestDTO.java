package com.univates.fishing_backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

public record LoginRequestDTO(
        @Schema(description = "Registered e-mail", example = "joao@univates.br")
                @NotBlank(message = "E-mail is required")
                String email,
        @Schema(description = "Password", example = "strongPass123") @NotBlank(message = "Password is required")
                String password) {}
