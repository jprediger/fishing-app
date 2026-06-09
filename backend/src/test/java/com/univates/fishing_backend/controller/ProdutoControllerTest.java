package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.dto.ProdutoRequestDTO;
import com.univates.fishing_backend.dto.ProdutoResponseDTO;
import com.univates.fishing_backend.dto.ProdutoUpdateDTO;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.service.ProdutoService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import com.univates.fishing_backend.config.TestcontainersConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;
import tools.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class ProdutoControllerTest {

    @Autowired
    private WebApplicationContext ctx;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private ProdutoService produtoService;

    private MockMvc mockMvc;

    @BeforeEach
    void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(ctx).build();
    }

    private ProdutoResponseDTO responseExemplo() {
        return new ProdutoResponseDTO(1L, "Teclado", "Mecânico",
            new BigDecimal("349.90"), 10, true, OffsetDateTime.now(), null);
    }

    @Test
    void listarTodos_retorna200ComPage() throws Exception {
        when(produtoService.listarTodos(any(Pageable.class)))
            .thenReturn(new PageImpl<>(List.of(responseExemplo())));

        mockMvc.perform(get("/api/produtos"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content[0].nome").value("Teclado"));
    }

    @Test
    void buscarPorId_produtoExiste_retorna200() throws Exception {
        when(produtoService.buscarPorId(1L)).thenReturn(responseExemplo());

        mockMvc.perform(get("/api/produtos/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1));
    }

    @Test
    void buscarPorId_produtoNaoExiste_retorna404() throws Exception {
        when(produtoService.buscarPorId(99L))
            .thenThrow(new ResourceNotFoundException("Produto não encontrado com id: 99"));

        mockMvc.perform(get("/api/produtos/99"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void criar_bodyValido_retorna201() throws Exception {
        ProdutoRequestDTO request = new ProdutoRequestDTO("Teclado", null,
            new BigDecimal("349.90"), 10);

        when(produtoService.criar(any())).thenReturn(responseExemplo());

        mockMvc.perform(post("/api/produtos")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsBytes(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1));
    }

    @Test
    void criar_nomeEmBranco_retorna400() throws Exception {
        String json = "{\"nome\":\"\",\"preco\":349.90,\"quantidadeEstoque\":10}";

        mockMvc.perform(post("/api/produtos")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void criar_precoNegativo_retorna400() throws Exception {
        String json = "{\"nome\":\"Teclado\",\"preco\":-1,\"quantidadeEstoque\":10}";

        mockMvc.perform(post("/api/produtos")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void atualizar_bodyValido_retorna200() throws Exception {
        ProdutoUpdateDTO request = new ProdutoUpdateDTO("Teclado Pro", null,
            new BigDecimal("399.90"), 8, true);

        ProdutoResponseDTO atualizado = new ProdutoResponseDTO(1L, "Teclado Pro", null,
            new BigDecimal("399.90"), 8, true, OffsetDateTime.now(), OffsetDateTime.now());

        when(produtoService.atualizar(eq(1L), any())).thenReturn(atualizado);

        mockMvc.perform(put("/api/produtos/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsBytes(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.nome").value("Teclado Pro"));
    }

    @Test
    void atualizar_produtoNaoExiste_retorna404() throws Exception {
        ProdutoUpdateDTO request = new ProdutoUpdateDTO("X", null, BigDecimal.ONE, 1, true);

        when(produtoService.atualizar(eq(99L), any()))
            .thenThrow(new ResourceNotFoundException("Produto não encontrado com id: 99"));

        mockMvc.perform(put("/api/produtos/99")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsBytes(request)))
            .andExpect(status().isNotFound());
    }

    @Test
    void deletar_produtoExiste_retorna204() throws Exception {
        doNothing().when(produtoService).deletar(1L);

        mockMvc.perform(delete("/api/produtos/1"))
            .andExpect(status().isNoContent());
    }

    @Test
    void deletar_produtoNaoExiste_retorna404() throws Exception {
        doThrow(new ResourceNotFoundException("Produto não encontrado com id: 99"))
            .when(produtoService).deletar(99L);

        mockMvc.perform(delete("/api/produtos/99"))
            .andExpect(status().isNotFound());
    }
}
