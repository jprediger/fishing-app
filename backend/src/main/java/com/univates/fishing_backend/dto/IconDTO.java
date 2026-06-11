package com.univates.fishing_backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

public record IconDTO(

    @Schema(description = "Caminho/URL do ícone do peixe", example = "/icons/tucunare.png")
    @NotBlank(message = "O caminho do ícone é obrigatório")
    String path

) {}
