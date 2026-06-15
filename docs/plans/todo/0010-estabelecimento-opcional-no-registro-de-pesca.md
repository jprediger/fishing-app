# Plano 0010 — Estabelecimento opcional no registro de pesca

- **Status:** Proposto
- **Data:** 2026-06-15
- **Relacionado:** [Spec 0001 (registro de pesca)](../../specs/0001-registro-de-pesca.md),
  [ADR-0003 (associação a estabelecimento)](../../adr/0003-associacao-opcional-de-catch-record-a-establishment.md),
  [Plano 0004 (registro de pesca)](../done/0004-registro-de-pesca.md),
  [Plano 0005 (nearest + marcar ponto)](../done/0005-nearest-marcar-ponto-e-mapa-real.md),
  [Plano 0008 (feed de registros do corpo d'água)](../done/0008-feed-de-registros-do-corpo-dagua.md)

## Objetivo

Estender o fluxo de `CatchRecord` para permitir associação opcional a um
`Establishment`, sem substituir o `WaterBody` obrigatório. A entrega inclui:

- vínculo opcional `establishment_id` no backend;
- validação por categoria elegível + raio curto;
- sugestão de estabelecimentos no fluxo de marcar ponto;
- CTA e feed próprio para `PESQUEIRO` e `CLUBE` no mapa;
- ajuste do formulário e dos modelos do app.

## Diagnóstico (situação atual)

- **Domínio/documentação:** `CatchRecord` já foi documentado como pertencente a
  um `WaterBody`, e o novo papel de `Establishment` já foi fechado no
  [ADR-0003](../../adr/0003-associacao-opcional-de-catch-record-a-establishment.md):
  vínculo opcional, explícito, restrito a `PESQUEIRO`/`CLUBE`, com raio inicial
  de `200 m`.
- **Backend `catch_record`:** hoje o registro não possui `establishment_id`.
  `CatchService#create/update` carregam apenas `WaterBody` e `Fish`; não existe
  validação nem serialização de estabelecimento no DTO.
- **Backend `establishments`:** o endpoint atual `GET /api/establishments`
  combina texto, categoria e proximidade, mas não distingue estabelecimentos
  associáveis dos demais nem expõe a regra de raio de associação.
- **App `MapScreen`:** tocar `WaterBody` já abre card com `Criar registro aqui`
  e `Ver registros`. Tocar `Establishment` abre apenas card informativo, sem CTAs
  de criação/feed. O modo de marcar ponto só resolve `nearest water body`.
- **App `CatchDraft` / `CatchRecord`:** hoje carregam apenas `waterBody`; não há
  campo opcional de `Establishment` em memória nem no payload enviado à API.
- **Edição:** nesta fase o ponto do `CatchRecord` não é editável após a criação,
  então a regra de raio precisa ser aplicada na criação e na edição da
  associação, mas não há reconciliação de ponto em movimento.

## Decisões fechadas (grilling)

| Tema | Decisão |
|---|---|
| Papel de `Establishment` | `CatchRecord` continua pertencendo a um `WaterBody`; `Establishment` é vínculo opcional adicional. |
| Forma de associação | Sempre explícita do usuário; proximidade só sugere, nunca associa sozinha. |
| Cardinalidade | Um `CatchRecord` pode ter **0..1** `Establishment`. |
| Significado | Nesta fase, associar significa **"pescou no estabelecimento ou no seu entorno imediato"**. |
| Categorias elegíveis | Apenas `PESQUEIRO` e `CLUBE`. |
| Raio | Definido no backend, exibido pelo app; valor inicial **`200 m`**. |
| Oferta na UI | O app só mostra como opção os estabelecimentos elegíveis já dentro do raio. |
| Card de categorias não elegíveis | Continuam como POIs informativos, sem `Criar novo` nem `Ver registros`. |
| Feed do estabelecimento | Mostra apenas registros explicitamente associados àquele estabelecimento, respeitando as regras gerais de privacidade. |
| Criação iniciada por estabelecimento | Entra em modo de marcar ponto, centralizado no estabelecimento e com associação pré-marcada enquanto o ponto estiver dentro do raio. |
| Saída do raio no fluxo iniciado por estabelecimento | O estabelecimento permanece visível, mas desmarcado e indisponível até o ponto voltar ao raio. |
| Edição da associação | Pode adicionar, trocar ou remover `Establishment`, desde que categoria e raio continuem válidos. |

## Escopo da entrega

### Inclui

- migration com `catch_record.establishment_id`;
- DTOs e entidade com `Establishment` opcional;
- validação de categoria elegível e distância no backend;
- filtro `GET /api/catches?establishmentId=...`;
- busca/sugestão de estabelecimentos elegíveis por proximidade;
- CTAs específicos no mapa para `PESQUEIRO`/`CLUBE`;
- campo opcional de associação no `CatchDraft` e no `CatchFormScreen`;
- feed de registros associados ao estabelecimento.

### Não inclui

- permitir `CatchRecord` sem `WaterBody`;
- associação automática silenciosa ao estabelecimento mais próximo;
- associação a categorias como `LOJA_PESCA`, `ISCARIA`, `MARINA`, `RAMPA`, `OUTRO`;
- edição do ponto do `CatchRecord` após criar;
- descoberta por proximidade geográfica no feed do estabelecimento.

## Backend

### Migration e modelo

1. Criar a próxima migration Flyway livre para:
   - adicionar `establishment_id BIGINT NULL` em `catch_record`;
   - criar FK para `establishment(id)`;
   - criar índice em `catch_record(establishment_id)`.
2. Atualizar `entity/CatchRecord.java` com:
   - `@ManyToOne(optional = true, fetch = LAZY)` para `Establishment`;
   - `@JoinColumn(name = "establishment_id")`.
3. Manter `water_body_id` obrigatório e sem alteração semântica.

### DTOs e contrato da API

4. Estender `CatchRequestDTO` com `Long establishmentId` opcional.
5. Estender `CatchResponseDTO` para devolver `establishment` resumido quando
   existir.
6. Reaproveitar `EstablishmentResponseDTO` como base de serialização, ou criar um
   DTO enxuto de resumo se o payload atual estiver grande demais para o feed.

### Regras de negócio

7. Injetar `EstablishmentRepository` ou `EstablishmentService` em `CatchService`.
8. Em `create/update`:
   - se `establishmentId == null`, salvar normalmente;
   - se vier valor, carregar o estabelecimento;
   - validar categoria elegível (`PESQUEIRO` ou `CLUBE`);
   - validar distância entre `location` e `establishment.geom` `<= 200 m`
     usando PostGIS/JTS, com a fonte da verdade no backend;
   - rejeitar violação com erro de negócio claro (`400`).
9. Como o ponto não é editável nesta fase no app, a validação de raio ainda
   deve existir no backend para proteger API direta, cliente antigo e evolução futura.

### Busca e feed por estabelecimento

10. Estender `CatchController#findAll` / `CatchService.findAll(...)` / `CatchRepository`
    com `establishmentId` opcional:
    - `GET /api/catches?establishmentId=X`;
    - ordenação `createdAt desc`, no mesmo padrão já usado por `waterBodyId`.
11. Garantir que o filtro por `establishmentId` liste apenas registros
    explicitamente associados, nunca por proximidade.
12. Manter a privacidade do ponto via `toDto(...)`: visitantes continuam vendo
    apenas registros públicos; o dono vê os seus conforme a regra já existente.

### Busca de estabelecimentos elegíveis

13. Evoluir `GET /api/establishments` com suporte ao fluxo de associação.
    Duas opções aceitáveis:
    - adicionar flags como `associableOnly=true` e `withinCatchRadius=true`; ou
    - criar endpoint específico, ex. `GET /api/establishments/associable`.
14. Regras dessa busca:
    - exigir `lat` + `lon`;
    - filtrar por categorias elegíveis;
    - aplicar o raio configurado no backend;
    - ordenar por distância;
    - retornar `distanceMeters`.
15. Expor também ao app o raio efetivo usado na busca, para a UI explicar a regra.
    Pode ser no próprio payload, em metadata da resposta, ou em endpoint/config
    separado, desde que a fonte permaneça no backend.

### Testes backend

16. Cobrir:
    - criação com `establishmentId` válido;
    - rejeição por categoria não elegível;
    - rejeição por distância > `200 m`;
    - ausência de associação quando `establishmentId` não vem;
    - listagem por `establishmentId`;
    - privacidade preservada no feed do estabelecimento.

## Frontend (`app/`)

### Modelos e serviços

17. Atualizar `models/catch_record.dart`:
    - adicionar `Establishment? establishment`;
    - incluir parse no `fromJson`;
    - incluir `establishmentId` opcional no `CatchCreateRequest`.
18. Atualizar `models/catch_draft.dart`:
    - adicionar `Establishment? establishment`;
    - inicialização via criação e edição;
    - setters para adicionar/trocar/remover associação.
19. Evoluir `services/catch_service.dart`:
    - enviar `establishmentId` quando presente;
    - aceitar filtro `establishmentId` na listagem.
20. Evoluir `services/establishment_service.dart`:
    - adicionar método dedicado para buscar estabelecimentos associáveis por ponto
      e raio efetivo;
    - manter o `search()` genérico existente para a aba de locais.

### `MapScreen`

21. Diferenciar claramente dois tipos de card de estabelecimento:
    - **Associáveis (`PESQUEIRO`/`CLUBE`)**:
      - `Ver registros`;
      - `Criar novo`.
    - **Não associáveis**:
      - apenas informações básicas.
22. Fluxo `Ver registros`:
    - abrir feed filtrado por `establishmentId`;
    - nunca misturar registros apenas próximos.
23. Fluxo `Criar novo` a partir do estabelecimento:
    - entrar em modo de marcar ponto;
    - centralizar no estabelecimento;
    - manter associação pré-marcada enquanto o ponto estiver no raio;
    - se sair do raio, exibir o estabelecimento desmarcado/desabilitado.
24. Fluxo genérico de marcar ponto:
    - continuar resolvendo `nearest water body`;
    - em paralelo, carregar estabelecimentos elegíveis no raio;
    - mostrar sugestão explícita, sem pré-marcar;
    - permitir abrir o formulário com ou sem associação.

### `CatchFormScreen`

25. Incluir uma seção explícita de associação opcional:
    - label do estabelecimento selecionado;
    - ação para remover/trocar;
    - lista curta de opções sugeridas quando houver.
26. Como o ponto não é editável nesta fase, o formulário não precisa redesenhar
    o mapa; só precisa refletir e ajustar a associação já compatível com o ponto.
27. Na edição do registro:
    - permitir adicionar/trocar/remover `Establishment`;
    - restringir as opções ao conjunto elegível para o ponto atual do registro.

### Feed por estabelecimento

28. Reaproveitar o padrão do `CatchFeedScreen` do `WaterBody`, com uma tela irmã
    ou parametrização do feed atual.
29. O AppBar e os textos devem deixar explícito que se trata de registros
    **associados** ao estabelecimento, não apenas próximos.

### Testes de widget

30. Cobrir:
    - card de `PESQUEIRO`/`CLUBE` com CTAs;
    - card de categoria não elegível sem CTAs;
    - criação iniciada por estabelecimento entra em modo de marcação;
    - sugestão explícita no modo de marcar ponto genérico;
    - envio de `establishmentId` no save;
    - feed do estabelecimento filtrado corretamente.

## Ordem de execução

1. Backend: migration + entidade + DTOs.
2. Backend: validação de categoria/raio em `CatchService`.
3. Backend: filtro `GET /api/catches?establishmentId=...`.
4. Backend: busca de estabelecimentos associáveis por proximidade.
5. Front: modelos (`CatchRecord`, `CatchDraft`) e serviços.
6. Front: CTAs e estados de `Establishment` no `MapScreen`.
7. Front: seção opcional de associação no `CatchFormScreen`.
8. Front: feed de registros do estabelecimento.
9. Testes backend + widget.
10. Validação completa com `bash scripts/validate.sh`.

## Critérios de aceite

- [ ] `CatchRecord` continua exigindo `waterBodyId`, mas aceita `establishmentId` opcional.
- [ ] Apenas `PESQUEIRO` e `CLUBE` podem ser associados.
- [ ] O backend rejeita associação fora do raio configurado.
- [ ] O app só oferece estabelecimentos elegíveis já dentro do raio.
- [ ] Tocar `PESQUEIRO`/`CLUBE` no mapa oferece `Ver registros` e `Criar novo`.
- [ ] Tocar categorias não elegíveis continua mostrando apenas card informativo.
- [ ] Iniciar criação por estabelecimento entra em modo de marcar ponto centrado nele e com associação pré-marcada enquanto válida.
- [ ] O formulário permite remover ou trocar a associação opcional antes de salvar.
- [ ] `GET /api/catches?establishmentId=X` retorna apenas registros explicitamente associados ao estabelecimento.
- [ ] A privacidade do ponto continua respeitada no feed do estabelecimento.
- [ ] Suíte `bash scripts/validate.sh` verde.

## Riscos / armadilhas

- **Semântica errada por categoria:** se a whitelist vazar para `LOJA_PESCA` ou
  `ISCARIA`, a regra “pescou no estabelecimento” perde consistência.
- **Validação duplicada incoerente:** a UI pode sugerir um conjunto e o backend
  aceitar outro. O backend precisa ser a autoridade do raio e das categorias.
- **Acoplamento com o feed do `WaterBody`:** evitar duplicar tela e lógica demais;
  vale parametrizar onde a semântica continuar igual.
- **Dados OSM / GPS imperfeitos:** `200 m` é um default razoável, mas pode exigir
  ajuste futuro; por isso o raio deve ficar configurável no backend.
- **Regressão no fluxo atual de marcar ponto:** a busca de estabelecimentos não
  pode atrasar nem bloquear a resolução do `nearest water body`, que continua
  sendo o caminho principal para criar o registro.

## Questões em aberto

_Nenhuma — decisões fechadas no grilling e no ADR-0003._
