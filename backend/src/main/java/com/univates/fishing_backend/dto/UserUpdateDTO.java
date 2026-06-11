package com.univates.fishing_backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UserUpdateDTO(

    @Schema(description = "User name", example = "John Smith")
    @NotBlank(message = "Name is required")
    String name,

    @Schema(description = "User e-mail", example = "john@example.com")
    @NotBlank(message = "E-mail is required")
    @Email(message = "Invalid e-mail")
    String email,

    @Schema(description = "New password (optional; if blank keeps the current one)", example = "newPassword123")
    @Size(min = 6, message = "Password must be at least 6 characters")
    String password,

    @Schema(description = "User active status", example = "true")
    @NotNull(message = "Active status is required")
    Boolean active

) {}
