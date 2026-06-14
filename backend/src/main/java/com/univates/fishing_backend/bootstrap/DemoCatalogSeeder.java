package com.univates.fishing_backend.bootstrap;

import com.univates.fishing_backend.entity.Fish;
import com.univates.fishing_backend.entity.FishType;
import com.univates.fishing_backend.entity.Icon;
import com.univates.fishing_backend.entity.Produto;
import com.univates.fishing_backend.repository.FishRepository;
import com.univates.fishing_backend.repository.ProdutoRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

/**
 * Catálogo de exemplo (peixes e produtos) para a app subir demonstrável.
 * Só em ambientes com {@code app.seed.demo.enabled=true}. Idempotente.
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.seed.demo.enabled", havingValue = "true")
public class DemoCatalogSeeder implements DataSeeder {

    private final FishRepository fishRepository;
    private final ProdutoRepository produtoRepository;

    @Override
    public int order() {
        return 20;
    }

    @Override
    @Transactional
    public void run() {
        seedFish("Dourado", "Peixe esportivo de água doce, comum no Rio Uruguai.", "RS", FishType.FRESHWATER);
        seedFish("Traíra", "Predador voraz de lagoas e açudes.", "RS", FishType.FRESHWATER);
        seedFish("Tainha", "Espécie estuarina de água salobra.", "Litoral", FishType.BRACKISH);

        if (produtoRepository.count() == 0) {
            produtoRepository.save(Produto.builder()
                .nome("Vara de pesca 1,80m")
                .descricao("Vara telescópica em fibra de carbono.")
                .preco(new BigDecimal("149.90"))
                .quantidadeEstoque(20)
                .ativo(true)
                .build());
            produtoRepository.save(Produto.builder()
                .nome("Molinete 4000")
                .descricao("Molinete com 5 rolamentos.")
                .preco(new BigDecimal("199.90"))
                .quantidadeEstoque(15)
                .ativo(true)
                .build());
            log.info("Seed demo: produtos de exemplo criados");
        }
    }

    private void seedFish(String name, String description, String region, FishType type) {
        if (fishRepository.existsByName(name)) {
            return;
        }
        fishRepository.save(Fish.builder()
            .name(name)
            .description(description)
            .region(region)
            .type(type)
            .icon(new Icon(null))
            .build());
        log.info("Seed demo: peixe de exemplo criado ({})", name);
    }
}
