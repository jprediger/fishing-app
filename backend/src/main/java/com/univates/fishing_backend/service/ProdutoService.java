package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.ProdutoRequestDTO;
import com.univates.fishing_backend.dto.ProdutoResponseDTO;
import com.univates.fishing_backend.dto.ProdutoUpdateDTO;
import com.univates.fishing_backend.entity.Produto;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.ProdutoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional
public class ProdutoService {

    private final ProdutoRepository produtoRepository;

    @Transactional(readOnly = true)
    public Page<ProdutoResponseDTO> listarTodos(Pageable pageable) {
        return produtoRepository.findAll(pageable).map(this::toResponseDTO);
    }

    @Transactional(readOnly = true)
    public ProdutoResponseDTO buscarPorId(Long id) {
        return produtoRepository.findById(id)
            .map(this::toResponseDTO)
            .orElseThrow(() -> new ResourceNotFoundException("Produto não encontrado com id: " + id));
    }

    public ProdutoResponseDTO criar(ProdutoRequestDTO dto) {
        Produto produto = Produto.builder()
            .nome(dto.nome())
            .descricao(dto.descricao())
            .preco(dto.preco())
            .quantidadeEstoque(dto.quantidadeEstoque())
            .build();
        return toResponseDTO(produtoRepository.save(produto));
    }

    public ProdutoResponseDTO atualizar(Long id, ProdutoUpdateDTO dto) {
        Produto produto = produtoRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Produto não encontrado com id: " + id));

        produto.setNome(dto.nome());
        produto.setDescricao(dto.descricao());
        produto.setPreco(dto.preco());
        produto.setQuantidadeEstoque(dto.quantidadeEstoque());
        produto.setAtivo(dto.ativo());

        return toResponseDTO(produtoRepository.save(produto));
    }

    public void deletar(Long id) {
        if (!produtoRepository.existsById(id)) {
            throw new ResourceNotFoundException("Produto não encontrado com id: " + id);
        }
        produtoRepository.deleteById(id);
    }

    private ProdutoResponseDTO toResponseDTO(Produto produto) {
        return new ProdutoResponseDTO(
            produto.getId(),
            produto.getNome(),
            produto.getDescricao(),
            produto.getPreco(),
            produto.getQuantidadeEstoque(),
            produto.getAtivo(),
            produto.getCriadoEm(),
            produto.getAtualizadoEm()
        );
    }
}
