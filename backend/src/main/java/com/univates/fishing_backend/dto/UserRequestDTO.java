package com.univates.fishing_backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UserRequestDTO(

    @Schema(description = "User name", example = "John Smith")
    @NotBlank(message = "Name is required")
    String name,

    @Schema(description = "User e-mail", example = "john@example.com")
    @NotBlank(message = "E-mail is required")
    @Email(message = "Invalid e-mail")
    String email,

    @Schema(description = "User password", example = "password123")
    @NotBlank(message = "Password is required")
    @Size(min = 6, message = "Password must be at least 6 characters")
    String password

) {}
