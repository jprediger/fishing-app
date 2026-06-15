package com.univates.fishing_backend.dto;

import com.univates.fishing_backend.entity.FishType;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Payload de criação/atualização de um peixe. Os campos são idênticos em ambas
 * as operações, por isso um único DTO é reutilizado.
 */
public record FishRequestDTO(
        @Schema(description = "Nome da espécie", example = "Tucunaré") @NotBlank(message = "O nome é obrigatório")
                String name,
        @Schema(
                        description = "Descrição da espécie",
                        example = "Peixe predador de água doce, popular na pesca esportiva")
                String description,
        @Schema(description = "Região onde é encontrado", example = "Bacia Amazônica") String region,
        @Schema(description = "Tipo (habitat) do peixe", example = "FRESHWATER")
                @NotNull(message = "O tipo do peixe é obrigatório")
                FishType type,
        @Schema(description = "Ícone respectivo do peixe") @NotNull(message = "O ícone é obrigatório") @Valid
                IconDTO icon) {}
