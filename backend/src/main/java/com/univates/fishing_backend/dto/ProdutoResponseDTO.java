package com.univates.fishing_backend.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ProdutoResponseDTO(
    Long id,
    String nome,
    String descricao,
    BigDecimal preco,
    Integer quantidadeEstoque,
    Boolean ativo,
    OffsetDateTime criadoEm,
    OffsetDateTime atualizadoEm
) {}
