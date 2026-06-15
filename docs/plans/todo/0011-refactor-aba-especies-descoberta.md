# Plano 0011 — Refactor da aba Buscar para Espécies + descoberta por espécie

- **Status:** Proposto
- **Data:** 2026-06-15
- **Relacionado:** [Contexto do projeto](../../CONTEXT.md),
  [Spec 0001 (registro de pesca)](../../specs/0001-registro-de-pesca.md),
  [Plano 0007 (pescas no mapa)](../done/0007-pescas-no-mapa.md),
  [Plano 0008 (feed de registros do corpo d'água)](../done/0008-feed-de-registros-do-corpo-dagua.md)

## Objetivo

Substituir a aba **"Buscar"** por **"Espécies"** e evoluir a tela atual de
catálogo para uma experiência de **descoberta por espécie**:

- a raiz continua sendo uma lista pesquisável de **Espécies**;
- tocar numa espécie abre uma tela de descoberta com **resumo da espécie**;
- o modo padrão mostra **Corpos d'água** agregados para aquela espécie;
- o modo alternativo mostra **Registros de pesca** da espécie;
- tocar num corpo d'água abre o feed **filtrado pela espécie**;
- o CTA **"Ver no mapa"** centraliza o corpo d'água no mapa.

## Diagnóstico (situação atual)

- **Frontend:**
  - `HomeShell` ainda nomeia a aba como **"Buscar"** e aponta para
    `SearchScreen`.
  - `SearchScreen` é um **catálogo puro** de espécies: busca por nome, habitat e
    região; abre um bottom sheet de detalhes, mas **não navega** para uma
    experiência de descoberta.
  - `CatchFeedScreen` já existe (Plano 0008), mas hoje lista registros por
    `waterBodyId` sem contexto de espécie.
  - `HomeShell` + `MapScreen` já sabem focar **Establishment**, mas **não**
    sabem focar **WaterBody** por navegação externa.
- **Backend:**
  - `GET /api/fish` e `GET /api/fish/{id}` retornam o catálogo básico de
    espécies, **sem** sinal de atividade (`waterBodyCount`).
  - `GET /api/catches` já aceita `speciesId`, `waterBodyId` e `userId`, mas o
    caminho com `waterBodyId` no `CatchService` hoje **ignora** `speciesId`; isso
    conflita com o drill-down decidido para esta feature.
  - **Não existe** endpoint agregado do tipo
    `Espécie -> Corpos d'água (count + lastCatchAt)`.
- **Domínio / UX já fechados no grilling:**
  - a aba continua catálogo **primeiro**, descoberta **depois**;
  - o modo padrão da descoberta é **Corpos d'água**;
  - o modo alternativo é **Registros**;
  - espécies sem atividade continuam visíveis, com estado textual explícito;
  - `RIVER_ONLY` participa normalmente da descoberta por espécie; só o ponto
    exato continua privado.

## Decisões fechadas (grilling)

| Tema | Decisão |
|---|---|
| Nome da aba | **Espécies** |
| Tela raiz | Mantém o catálogo pesquisável atual, com busca por **nome + habitat + região** |
| Ordenação da raiz | **Alfabética** |
| Sinal de atividade no card da espécie | **Quantidade de corpos d'água** com registros daquela espécie |
| Espécie sem atividade | Continua visível, com texto como **"Sem registros ainda"** |
| Entrada da descoberta | Tocar na espécie abre uma tela com **resumo da espécie** |
| Modos da descoberta | `Corpos d'água` (padrão) e `Registros` em **segmented control** |
| Lista padrão | **Corpos d'água** agregados, ordenados por **maior número de registros** |
| Card do corpo d'água | Nome, `N registros`, **data do último registro** e CTA **"Ver no mapa"** |
| Ação principal do card | Abre os **registros daquele corpo d'água filtrados pela espécie** |
| CTA "Ver no mapa" | Centraliza o **WaterBody** no mapa, **sem** aplicar filtro visual de espécie |
| Modo `Registros` | Lista plana de todos os registros da espécie, ordenados por **mais recentes** |
| Drill-down do corpo d'água | Reusa o feed existente, mas **filtrado por `speciesId`** |
| Título do drill-down | **WaterBody** como título; espécie + quantidade como contexto secundário |
| Proximidade | **Sem geolocalização do usuário** nesta entrega |
| Agregação | Vem do **backend**, não calculada no app |
| Recurso da agregação | **`/api/fish/{id}/water-bodies`** |

## Contratos propostos

### Backend

1. **Estender `FishResponseDTO`** com `Long waterBodyCount`:
   - usado na lista raiz da aba **Espécies**;
   - disponível em `GET /api/fish` e `GET /api/fish/{id}`;
   - representa a quantidade de **corpos d'água distintos** com pelo menos um
     `CatchRecord` daquela espécie.

2. **Novo endpoint agregado**:
   - `GET /api/fish/{id}/water-bodies?page=0&size=20`
   - retorno paginado de `FishWaterBodySummaryDTO` com:
     - `waterBody`
     - `catchCount`
     - `lastCatchAt`
   - ordenação default:
     - `catchCount desc`
     - `lastCatchAt desc`
     - `waterBody.name asc` (desempate estável)

3. **Reuso do feed existente**:
   - `GET /api/catches?speciesId=X` para o modo `Registros`;
   - `GET /api/catches?waterBodyId=Y&speciesId=X` para o drill-down do corpo
     d'água;
   - exige corrigir o `CatchService.findAll(...)` para **combinar**
     `waterBodyId + speciesId`, em vez de ignorar a espécie quando há corpo
     d'água.

### Frontend

4. **Tela raiz da aba**:
   - continua carregando espécies do recurso `/api/fish`;
   - mostra `waterBodyCount` no card;
   - quando `waterBodyCount == 0`, exibe **"Sem registros ainda"**;
   - tocar na espécie abre a tela de descoberta.

5. **Tela de descoberta por espécie**:
   - cabeçalho com resumo da espécie (`habitat`, `região`, `descrição`);
   - `SegmentedButton` com `Corpos d'água` e `Registros`;
   - modo padrão = `Corpos d'água`.

6. **Navegação para o mapa**:
   - `HomeShell` e `MapScreen` precisam aceitar foco explícito em `WaterBody`;
   - espécie sem registros ainda pode abrir o mapa geral com contexto textual da
     espécie, sem filtro visual.

## Etapas

### Backend

1. **Atividade na espécie (`waterBodyCount`)**
   - Estender `FishResponseDTO` com `waterBodyCount`.
   - Atualizar `FishService.findAll/findById`.
   - Implementar agregação sem N+1:
     - para a lista paginada, buscar os `fishIds` da página;
     - resolver `COUNT(DISTINCT water_body_id)` em lote por espécie;
     - aplicar os valores ao DTO da página atual.
   - Para `findById`, resolver o mesmo contador para a espécie única.

2. **Agregação `Espécie -> Corpos d'água`**
   - Criar `FishWaterBodySummaryDTO`.
   - Criar consulta agregada em `CatchRepository` (ou repositório custom
     dedicado) agrupando por `water_body_id`, filtrando por `species_id`,
     retornando:
     - corpo d'água
     - `COUNT(*) AS catchCount`
     - `MAX(created_at) AS lastCatchAt`
   - Expor `GET /api/fish/{id}/water-bodies`.
   - Paginar e ordenar no backend.

3. **Combinação `waterBodyId + speciesId` no feed**
   - Ajustar `CatchRepository` para variante
     `findByWaterBody_IdAndSpecies_Id(...)` (ou query equivalente).
   - Ajustar `CatchService.findAll(...)` para:
     - `waterBodyId != null && speciesId != null` → feed filtrado pelos dois;
     - `waterBodyId != null && speciesId == null` → comportamento atual;
     - manter `createdAt desc` nos fluxos de feed.

4. **Testes (backend)**
   - `FishControllerTest`/`FishServiceTest`:
     - `GET /api/fish` inclui `waterBodyCount`;
     - espécie sem registros retorna `0`;
     - `GET /api/fish/{id}/water-bodies` ordena por `catchCount desc`.
   - `CatchControllerTest`/`CatchServiceTest`:
     - `waterBodyId + speciesId` juntos retornam só registros daquela espécie
       naquele corpo d'água;
     - `RIVER_ONLY` continua sem `location` para não-dono.

### Front (`app/`)

5. **Raiz da aba**
   - Renomear o item do menu de `Buscar` para **`Espécies`** em `HomeShell`.
   - Evoluir `SearchScreen` para agir como catálogo de entrada da descoberta.
   - Atualizar o modelo `Fish` para aceitar `waterBodyCount`.
   - Atualizar `FishService.fetchFish(...)` para pedir ordenação alfabética
     (`sort=name,asc`) e expor o novo campo.
   - Manter filtros atuais (`nome + habitat + região`).

6. **Tela de descoberta da espécie**
   - Criar uma nova tela, por exemplo `SpeciesDiscoveryScreen`, recebendo `Fish`.
   - Cabeçalho com resumo da espécie.
   - `SegmentedButton` com dois modos:
     - **Corpos d'água**: fonte = `GET /api/fish/{id}/water-bodies`
     - **Registros**: fonte = `GET /api/catches?speciesId=X`
   - Estados: loading, vazio, erro, retry.

7. **Modo `Corpos d'água`**
   - Scroll infinito consumindo o endpoint agregado.
   - Card com:
     - nome do corpo d'água
     - quantidade de registros
     - data do último registro
     - CTA secundário **"Ver no mapa"** no trailing
   - Tocar no card abre o drill-down dos registros daquele corpo d'água.

8. **Drill-down `Espécie -> WaterBody -> Registros`**
   - Reusar `CatchFeedScreen` em vez de criar feed paralelo.
   - Evoluir `CatchFeedScreen` para aceitar `Fish? speciesFilter`.
   - Quando `speciesFilter != null`:
     - requisitar `GET /api/catches?waterBodyId=Y&speciesId=X`
     - título principal = nome do corpo d'água
     - subtítulo = `Registros de {Espécie} • N registros`
   - O CTA `Ver no mapa` permanece disponível nessa tela também.

9. **Modo `Registros`**
   - Reusar o card/feed já existente de registros.
   - Fonte = `GET /api/catches?speciesId=X&sort=createdAt,desc`.
   - Sem botão `Ver no mapa` em cada item da lista; a navegação para o mapa
     fica no detalhe do registro.

10. **Foco de `WaterBody` no mapa**
    - Evoluir `HomeShell` para armazenar um `focusedWaterBody`, análogo ao
      `focusEstablishment`.
    - Evoluir `MapScreen` para aceitar `focusWaterBody`:
      - centralizar no `centerLocation` (ou fallback) do corpo d'água;
      - selecionar o corpo d'água ao abrir;
      - opcionalmente abrir o card inferior daquele corpo.
    - Para a espécie sem registros:
      - navegar para a aba `Mapa`;
      - mostrar contexto textual breve, ex.:
        `Ainda não há registros de Traíra.`

11. **Testes de widget / integração**
    - `HomeShell`: label **Espécies** no lugar de `Buscar`.
    - Catálogo raiz:
      - mostra `N corpos d'água` quando houver atividade;
      - mostra `Sem registros ainda` quando `waterBodyCount == 0`.
    - `SpeciesDiscoveryScreen`:
      - abre no modo `Corpos d'água`;
      - alterna para `Registros`;
      - vazio/erro/retry.
    - `CatchFeedScreen` filtrado por espécie:
      - chama `waterBodyId + speciesId`;
      - mostra subtítulo correto.
    - Navegação `Ver no mapa`:
      - envia foco de `WaterBody` ao `MapScreen`.

## Ordem de execução

1. Backend: `waterBodyCount` em `FishResponseDTO`.
2. Backend: endpoint agregado `GET /api/fish/{id}/water-bodies`.
3. Backend: combinação `waterBodyId + speciesId` no `GET /api/catches`.
4. Front: `Fish`/`FishService` com `waterBodyCount` + ordenação alfabética.
5. Front: renomear aba para **Espécies** e evoluir a tela raiz.
6. Front: criar `SpeciesDiscoveryScreen`.
7. Front: adaptar `CatchFeedScreen` para filtro opcional por espécie.
8. Front: foco de `WaterBody` em `HomeShell`/`MapScreen`.
9. Testes backend + widget.

## Critérios de aceite

- [ ] A aba **Buscar** foi renomeada para **Espécies**.
- [ ] A lista raiz continua pesquisável por nome, habitat e região.
- [ ] Cada espécie mostra `N corpos d'água` ou `Sem registros ainda`.
- [ ] Tocar numa espécie abre a descoberta com resumo + modos
      `Corpos d'água` e `Registros`.
- [ ] O modo padrão `Corpos d'água` vem de endpoint agregado no backend.
- [ ] A lista agregada é ordenada por `catchCount desc`, com `lastCatchAt`
      visível no card.
- [ ] Tocar num corpo d'água abre somente os registros daquela espécie naquele
      corpo d'água.
- [ ] `Ver no mapa` centraliza o `WaterBody` no mapa.
- [ ] `RIVER_ONLY` continua participando da descoberta, sem expor ponto exato.
- [ ] `GET /api/catches?waterBodyId=Y&speciesId=X` funciona corretamente.
- [ ] Suíte relevante verde (`bash scripts/validate.sh --backend`,
      `bash scripts/validate.sh --frontend` e validação completa antes da entrega).

## Riscos / armadilhas

- **N+1 no catálogo de espécies:** `waterBodyCount` não pode virar uma query por
  espécie na página. Resolver em lote.
- **Ambiguidade no `GET /api/catches`:** o caminho com `waterBodyId` hoje já
  existe; ao combinar com `speciesId`, não quebrar os usos atuais do mapa e do
  feed genérico do corpo d'água.
- **Foco no mapa:** o app já resolve foco de `Establishment`, mas não de
  `WaterBody`. Reaproveitar o padrão sem duplicar estados conflitantes.
- **Dois feeds parecidos:** evitar criar uma segunda implementação paralela de
  feed por corpo d'água; o certo é parametrizar o `CatchFeedScreen` existente.
- **Ordenação alfabética:** preferir que o frontend peça explicitamente
  `sort=name,asc` em `/api/fish`, em vez de alterar o default global sem revisar
  os outros consumidores.
- **Espécie sem registros:** o CTA `Ver no mapa` não pode prometer filtro visual
  que ainda não existe; o mapa abre geral, só com contexto textual.

## Questões em aberto

_Nenhuma crítica para iniciar a implementação. Refinos visuais podem ser
decididos durante o frontend sem mudar o contrato principal._
