# Plano 0007 — Pescas no mapa (marcadores próprios vs. de outros + contagem por corpo d'água)

- **Status:** Proposto
- **Data:** 2026-06-15
- **Relacionado:** [Spec 0001 (registro de pesca)](../../specs/0001-registro-de-pesca.md),
  [ADR-0002 (privacidade do local)](../../adr/0002-privacidade-do-local-de-pesca.md),
  [Plano 0004 (registro de pesca)](./0004-registro-de-pesca.md),
  [Plano 0005 (nearest + mapa real)](../done/0005-nearest-marcar-ponto-e-mapa-real.md),
  [Plano 0008 (feed de registros)](./0008-feed-de-registros-do-corpo-dagua.md)

## Objetivo

Fazer as pescas registradas **aparecerem para outros usuários no mapa**. Todo
registro é público (não há registro privado). A privacidade existente é só a do
**ponto** (`LocationVisibility`, ver ADR-0002), que não muda aqui.

Regra de renderização (fechada no grilling):

- **`EXACT`** → marcador individual no ponto exato.
- **`RIVER_ONLY`** → **sem** marcador individual; só aparece via o corpo d'água
  (contagem no pin + feed do Plano 0008).
- A regra do pin vale **para todos** (próprio ou de outros): pin individual
  **se, e somente se, `LocationVisibility == EXACT`**.

Esta é a **Entrega 1**. O feed ("Ver registros") fica no [Plano 0008](./0008-feed-de-registros-do-corpo-dagua.md).

## Diagnóstico (situação atual)

- **Backend:** `CatchService.toDto` já aplica a privacidade do ponto
  (`location` nulo para não-dono quando `RIVER_ONLY`) e já expõe `mine`.
  `findAllInBbox` filtra pescas por viewport. **Não há** autor no
  `CatchResponseDTO` nem contagem de pescas por corpo d'água.
- **Front (`map_screen.dart`):**
  - `_catchMarkers` (linha ~868) já renderiza **um marcador por pesca**,
    incluindo `RIVER_ONLY` empilhadas no centroide do corpo d'água como pin
    "aproximado" (`Icons.place_outlined`, `cs.tertiary`). **Isso sai.**
  - Carregamento de pescas (`_loadCatches`) só dispara quando
    `widget.catchService != null` — **gate de teste** (linha ~189). Em produção
    `widget.catchService` é `null`, então **as pescas nunca carregam**.
  - Não há distinção de cor próprio vs. de outros (hoje a cor varia por
    aproximado vs. exato).
  - `_MapPin` (corpo d'água) não tem badge de contagem.
- **Paleta (`app_colors.dart`):** `markerWaterBody = secondary` (verde),
  `markerCatch = deep` (azul profundo), `markerEstablishment = sand` (reservado).

## Decisões fechadas (grilling)

| Tema | Decisão |
|---|---|
| Registro privado | **Descartado.** Todo registro é público; só o **ponto** tem privacidade (`LocationVisibility`). |
| Pin individual | **Só `EXACT`**, para todos. `RIVER_ONLY` nunca vira pin individual. |
| Próprio vs. outros (cor) | Cor por flag `mine`. **Próprio = turquesa `#2EC4B6`** (nova constante `markerCatchMine`); **outros = `deep`** (`markerCatchOther`, igual ao `markerCatch` atual). |
| Como o usuário sabe que há pescas | **Badge de contagem no pin do corpo d'água** (conta **todas** as pescas ali — exatas + river-only). |
| Fonte da contagem | **Campo `catchCount`** no `WaterBodyResponseDTO`, calculado no próprio `findInBbox` (um round-trip a menos; o mapa já carrega corpos d'água por viewport). |
| Autor | Novo objeto `author {id, name}` no `CatchResponseDTO`, em **toda** pesca. Só `name` é exposto (nunca e-mail). O `id` é o gancho para futuro "tocar autor → perfil" (não implementado agora). |
| Marcadores "aproximados" | **Removidos.** River-only não aparece mais empilhado no centroide. |

## Etapas

### Backend

1. **`CatchResponseDTO`** — novo campo `AuthorDTO author` (record `AuthorDTO(Long id, String name)`).
   - `CatchService.toDto` popula `author` a partir de `record.getUser()`
     (id + name). Sem e-mail.
   - `CatchControllerTest`/`CatchServiceTest`: asserir `author` presente
     (próprio e de outros); nunca expor e-mail.

2. **`WaterBodyResponseDTO`** — novo campo `Long catchCount` (nullable; `null`
   no `nearest`, preenchido no `findInBbox`).
   - `WaterBodyRepository.findInBbox`: adicionar subquery de contagem
     `(SELECT COUNT(*) FROM catch_record c WHERE c.water_body_id = water_body.id) AS catchCount`
     na projeção `WaterBodyViewportRow` (novo `Long getCatchCount()`).
   - `findNearest`: manter `catchCount` como `CAST(NULL AS bigint)` (não usado lá).
   - `WaterBodyService` mapeia o novo campo; `nearest` passa `null`.
   - Ajustar `WaterBodyServiceTest`/`WaterBodyRepositoryIntegrationTest` para a
     contagem por bbox.

### Front (`app/`)

3. **`app_colors.dart`** — novas constantes:
   ```dart
   static const Color markerCatchMine = Color(0xFF2EC4B6); // turquesa: pesca própria
   static const Color markerCatchOther = deep;             // pesca de outros
   ```
   (`markerCatch` pode permanecer como alias de `markerCatchOther`.)

4. **`models/water_body.dart`** — campo `int? catchCount` no parse de
   `WaterBody.fromJson` (`json['catchCount']`).

5. **`models/catch_record.dart`** — novo `CatchAuthor {int id, String name}` e
   campo `author` em `CatchRecord` (parse de `json['author']`, nullable defensivo).

6. **`map_screen.dart`:**
   - **Desfazer o gate de teste:** `_loadCatches` deve rodar em produção. Trocar
     a condição da linha ~189 (`if (widget.catchService != null)`) por carregar
     sempre (o `_catchService` já cai em `CatchService()` real por default).
   - **`_catchMarkers`:** renderizar pin **só** para `record.locationVisibility == EXACT`
     **e** `record.location != null`. River-only é ignorado (vai pro badge/feed).
     - Remover o ramo "aproximado" (`Icons.place_outlined`/`cs.tertiary`).
     - Cor: `record.mine ? AppColors.markerCatchMine : AppColors.markerCatchOther`.
     - Ícone único de pesca (`Icons.set_meal`).
   - **`_MapPin`:** aceitar `catchCount` e desenhar um **badge** (círculo pequeno
     no canto superior-direito com o número) quando `catchCount != null && > 0`.
     O `_markers` getter passa `body.catchCount` ao construir cada pin.

7. **Testes de widget** (`map_screen` com `catchService` injetado):
   - Pesca `EXACT` própria → pin turquesa; de outros → pin `deep`.
   - Pesca `RIVER_ONLY` → **não** gera pin individual.
   - Pin de corpo d'água com `catchCount > 0` exibe o badge com o número.

## Ordem de execução

1. Backend: `author` no DTO + `catchCount` no `findInBbox` (+ testes).
2. Front: paleta + modelos (`catchCount`, `author`).
3. Front: ungate `_loadCatches` + `_catchMarkers` (EXACT only, cor por `mine`).
4. Front: badge no `_MapPin`.
5. Testes de widget.

## Critérios de aceite

- [ ] Pescas de **outros** usuários aparecem no mapa em produção (sem injeção de teste).
- [ ] Pesca `EXACT` vira pin individual; `RIVER_ONLY` **não** vira pin.
- [ ] Pin de pesca própria é turquesa; de outros é `deep`.
- [ ] Pin do corpo d'água mostra badge com a contagem total de pescas ali.
- [ ] `CatchResponseDTO` traz `author {id, name}` (sem e-mail) em toda pesca.
- [ ] Marcadores "aproximados" empilhados no centroide foram removidos.
- [ ] Suíte (`bash scripts/validate.sh`) verde.

## Riscos / armadilhas

- **`COUNT(*)` por subquery no `findInBbox`:** com `LIMIT :maxFeatures` o custo é
  limitado, mas confirmar índice em `catch_record.water_body_id` (FK já deve
  criar; senão, adicionar na migration).
- **Gate de teste:** ao ungate `_loadCatches`, garantir que os testes que
  dependiam da ausência de pescas continuem válidos (injetar service vazio onde
  preciso).
- **Privacidade:** o `location` de `RIVER_ONLY` já vem `null` para não-dono — o
  filtro de pin por `EXACT` não pode reintroduzir o ponto via centroide.

## Questões em aberto

_Nenhuma — decisões fechadas no grilling._
