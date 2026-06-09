package com.univates.fishing_backend.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;

public record ProdutoUpdateDTO(

    @NotBlank(message = "Nome é obrigatório")
    String nome,

    String descricao,

    @NotNull(message = "Preço é obrigatório")
    @Positive(message = "Preço deve ser positivo")
    BigDecimal preco,

    @NotNull(message = "Quantidade em estoque é obrigatória")
    @Min(value = 0, message = "Estoque não pode ser negativo")
    Integer quantidadeEstoque,

    @NotNull(message = "Status ativo é obrigatório")
    Boolean ativo

) {}
