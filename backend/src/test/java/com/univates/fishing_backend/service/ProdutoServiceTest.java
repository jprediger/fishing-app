package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.ProdutoRequestDTO;
import com.univates.fishing_backend.dto.ProdutoResponseDTO;
import com.univates.fishing_backend.dto.ProdutoUpdateDTO;
import com.univates.fishing_backend.entity.Produto;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.ProdutoRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ProdutoServiceTest {

    @Mock
    private ProdutoRepository produtoRepository;

    @InjectMocks
    private ProdutoService produtoService;

    private Produto produtoExemplo() {
        return Produto.builder()
            .id(1L)
            .nome("Teclado")
            .descricao("Mecânico")
            .preco(new BigDecimal("349.90"))
            .quantidadeEstoque(10)
            .ativo(true)
            .criadoEm(OffsetDateTime.now())
            .build();
    }

    @Test
    void listarTodos_retornaPageMapeada() {
        Pageable pageable = PageRequest.of(0, 20);
        when(produtoRepository.findAll(pageable)).thenReturn(new PageImpl<>(List.of(produtoExemplo())));

        var resultado = produtoService.listarTodos(pageable);

        assertThat(resultado.getContent()).hasSize(1);
        assertThat(resultado.getContent().get(0).nome()).isEqualTo("Teclado");
    }

    @Test
    void buscarPorId_produtoExiste_retornaDTO() {
        when(produtoRepository.findById(1L)).thenReturn(Optional.of(produtoExemplo()));

        ProdutoResponseDTO resultado = produtoService.buscarPorId(1L);

        assertThat(resultado.id()).isEqualTo(1L);
        assertThat(resultado.nome()).isEqualTo("Teclado");
    }

    @Test
    void buscarPorId_produtoNaoExiste_lancaException() {
        when(produtoRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> produtoService.buscarPorId(99L))
            .isInstanceOf(ResourceNotFoundException.class)
            .hasMessageContaining("99");
    }

    @Test
    void criar_dtovalido_salvaERetornaDTO() {
        ProdutoRequestDTO dto = new ProdutoRequestDTO("Mouse", null, new BigDecimal("199.90"), 50);

        Produto salvo = Produto.builder()
            .id(2L).nome("Mouse").preco(new BigDecimal("199.90"))
            .quantidadeEstoque(50).ativo(true).criadoEm(OffsetDateTime.now())
            .build();

        when(produtoRepository.save(any())).thenReturn(salvo);

        ProdutoResponseDTO resultado = produtoService.criar(dto);

        assertThat(resultado.id()).isEqualTo(2L);
        assertThat(resultado.nome()).isEqualTo("Mouse");
        verify(produtoRepository).save(any(Produto.class));
    }

    @Test
    void atualizar_produtoExiste_atualizaCamposERetornaDTO() {
        Produto existente = produtoExemplo();
        ProdutoUpdateDTO dto = new ProdutoUpdateDTO("Teclado Pro", "Switch Red",
            new BigDecimal("399.90"), 8, true);

        Produto atualizado = Produto.builder()
            .id(1L).nome("Teclado Pro").descricao("Switch Red")
            .preco(new BigDecimal("399.90")).quantidadeEstoque(8)
            .ativo(true).criadoEm(existente.getCriadoEm())
            .build();

        when(produtoRepository.findById(1L)).thenReturn(Optional.of(existente));
        when(produtoRepository.save(any())).thenReturn(atualizado);

        ProdutoResponseDTO resultado = produtoService.atualizar(1L, dto);

        assertThat(resultado.nome()).isEqualTo("Teclado Pro");
        assertThat(resultado.preco()).isEqualByComparingTo("399.90");
    }

    @Test
    void atualizar_produtoNaoExiste_lancaException() {
        when(produtoRepository.findById(99L)).thenReturn(Optional.empty());
        ProdutoUpdateDTO dto = new ProdutoUpdateDTO("X", null, BigDecimal.ONE, 1, true);

        assertThatThrownBy(() -> produtoService.atualizar(99L, dto))
            .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void deletar_produtoExiste_chamaDeleteById() {
        when(produtoRepository.existsById(1L)).thenReturn(true);

        produtoService.deletar(1L);

        verify(produtoRepository).deleteById(1L);
    }

    @Test
    void deletar_produtoNaoExiste_lancaException() {
        when(produtoRepository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> produtoService.deletar(99L))
            .isInstanceOf(ResourceNotFoundException.class)
            .hasMessageContaining("99");
    }
}
