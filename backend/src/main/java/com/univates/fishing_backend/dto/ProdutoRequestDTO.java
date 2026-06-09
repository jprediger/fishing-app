package com.univates.fishing_backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;

public record ProdutoRequestDTO(

    @Schema(description = "Nome do produto", example = "Vara de pesca")
    @NotBlank(message = "Nome é obrigatório")
    String nome,

    @Schema(description = "Descrição opcional", example = "Carbono 2.4m")
    String descricao,

    @Schema(description = "Preço unitário", example = "199.90")
    @NotNull(message = "Preço é obrigatório")
    @Positive(message = "Preço deve ser positivo")
    BigDecimal preco,

    @Schema(description = "Quantidade em estoque", example = "10")
    @NotNull(message = "Quantidade em estoque é obrigatória")
    @Min(value = 0, message = "Estoque não pode ser negativo")
    Integer quantidadeEstoque

) {}
