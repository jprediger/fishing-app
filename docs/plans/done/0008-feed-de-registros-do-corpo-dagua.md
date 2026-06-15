# Plano 0008 — Feed de registros do corpo d'água ("Ver registros")

- **Status:** Proposto
- **Data:** 2026-06-15
- **Relacionado:** [Spec 0001 (registro de pesca)](../../specs/0001-registro-de-pesca.md),
  [ADR-0002 (privacidade do local)](../../adr/0002-privacidade-do-local-de-pesca.md),
  [Plano 0007 (pescas no mapa)](./0007-pescas-no-mapa.md)

## Objetivo

Ao tocar um corpo d'água no mapa, oferecer um botão **"Ver registros"** que abre
uma tela listando as pescas feitas ali, em estilo **feed de posts** (sem
curtidas/comentários por enquanto). É a **Entrega 2**, complemento do
[Plano 0007](./0007-pescas-no-mapa.md).

## Diagnóstico (situação atual)

- **Backend:** `GET /api/catches` filtra por `speciesId` e `bbox`, com sort
  default por `id` (mais antigo primeiro). **Não há** filtro por corpo d'água.
- **Front:** ao tocar um corpo d'água, `map_screen._buildSelectedBodyCard`
  mostra um card inferior com nome/tipo e o CTA "Criar registro aqui". **Não há**
  caminho para listar as pescas daquele corpo d'água. `CatchDetailScreen` (tela
  de detalhe completa de uma pesca) já existe e será **reusada** ao tocar um post.
- O `author {id, name}` no `CatchResponseDTO` é entregue no Plano 0007 (dependência).

## Decisões fechadas (grilling)

| Tema | Decisão |
|---|---|
| Escopo do feed | **Todas** as pescas daquele corpo d'água (exatas + river-only). É o histórico do pesqueiro, igual ao que a contagem do pin conta. |
| Interações | **Nenhuma** (sem curtidas/comentários) nesta entrega. |
| Endpoint | `GET /api/catches?waterBodyId=123` (novo filtro), reusando a paginação existente. |
| Ordenação | **`createdAt desc`** (mais recentes primeiro — quando foi postado, não quando foi pescado). |
| Paginação | `Page` existente, `size ~20`, **scroll infinito** no app. |
| Card do post | Autor (`+"Você"` se `mine`), espécie, data, **thumbnail** da 1ª foto (se houver), linha compacta de peso/comprimento, e a **linha de local** (ponto exato vs. "Local aproximado", como no preview do mapa). |
| Tocar o post | **Reusa `CatchDetailScreen`** (sem tela de detalhe paralela). |
| Autor clicável | Carregar `author.id` no card pensando em **futuro** "tocar autor → perfil"; a navegação para o perfil de outro usuário **não** é implementada agora. |

## Etapas

### Backend

1. **`CatchRepository`** — `Page<CatchRecord> findByWaterBody_Id(Long waterBodyId, Pageable pageable)`
   (e variante com `speciesId` se necessário, mas o feed não exige).
2. **`CatchService.findAll(...)`** — aceitar `waterBodyId` (nullable). Quando
   presente, usar `findByWaterBody_Id`; combina com a privacidade do ponto já
   existente em `toDto`.
3. **`CatchController#findAll`** — novo `@RequestParam(required=false) Long waterBodyId`,
   repassado ao service. A ordenação `createdAt desc` vem do `Pageable`
   (`@PageableDefault(size = 20, sort = "createdAt", direction = DESC)` para este
   endpoint, ou o app envia `sort=createdAt,desc`). **Decidir num lugar só** —
   preferir default no controller para o feed.
4. **Testes** — `CatchControllerTest`/`CatchServiceTest`: filtra por
   `waterBodyId`, ordena `createdAt desc`, respeita privacidade do ponto para
   não-dono, e o `author` aparece.

### Front (`app/`)

5. **`CatchService.list`** — aceitar `waterBodyId` (já tem `bbox`/`speciesId`);
   adicionar `sort=createdAt,desc` para o feed (ou método dedicado
   `listByWaterBody`).
6. **Nova tela `CatchFeedScreen`** (`screens/catch_feed_screen.dart`):
   - Recebe o `WaterBody` (nome no AppBar) e o `CatchService`.
   - Lista paginada com **scroll infinito** (`ScrollController` + carregar próxima
     página ao chegar perto do fim).
   - Cada item: `_CatchPostCard` com autor (+"Você"), espécie, data, thumbnail da
     1ª foto (via `catchService.uploadUrl(photo.filePath)`), peso/comprimento,
     linha de local. Tocar → `Navigator.push(CatchDetailScreen(...))`.
   - Estados: carregando, vazio ("Nenhum registro neste corpo d'água ainda."),
     erro (mensagem + retry).
7. **`map_screen.dart`** — no `_buildSelectedBodyCard` (e/ou `_SelectionBody`),
   adicionar botão **"Ver registros"** (secundário, ao lado de "Criar registro
   aqui") que faz `Navigator.push(CatchFeedScreen(body, catchService))`.
   - Mostrar a contagem (`body.catchCount`) no rótulo quando disponível
     (ex.: "Ver registros (3)").
8. **Testes de widget** — `CatchFeedScreen` com service injetado: renderiza posts,
   "Você" no próprio, estado vazio; tocar abre o detalhe. Botão "Ver registros"
   aparece no card do corpo d'água.

## Ordem de execução

1. Backend: filtro `waterBodyId` + ordenação `createdAt desc` (+ testes).
2. Front: `CatchService` com `waterBodyId`/sort.
3. Front: `CatchFeedScreen` (cards + scroll infinito + estados).
4. Front: botão "Ver registros" no card do corpo d'água.
5. Testes de widget.

## Critérios de aceite

- [ ] `GET /api/catches?waterBodyId=X` retorna só as pescas daquele corpo d'água,
      ordenadas por `createdAt desc`, paginadas, respeitando a privacidade do ponto.
- [ ] Tocar um corpo d'água mostra o botão "Ver registros" que abre o feed.
- [ ] O feed lista **todas** as pescas do corpo d'água em estilo post (autor,
      espécie, data, foto, peso/comprimento, local), com scroll infinito.
- [ ] Post próprio é marcado com "Você".
- [ ] Tocar um post abre a `CatchDetailScreen` existente.
- [ ] Sem curtidas/comentários.
- [ ] Suíte (`bash scripts/validate.sh`) verde.

## Riscos / armadilhas

- **Dependência do Plano 0007:** o `author` no DTO vem de lá; sequenciar 0007 → 0008.
- **Ordenação em dois lugares:** definir `createdAt desc` só no controller do feed
  para não conflitar com o sort default (`id`) usado pelo mapa/`bbox`.
- **Thumbnails:** as fotos são servidas por `/uploads/**`; usar
  `catchService.uploadUrl(...)` e tratar falha de imagem sem quebrar o card.
- **Privacidade:** river-only de outros aparece no feed sem o ponto exato
  ("Local aproximado") — o `location` já vem `null` do backend; o card não pode
  inferir o ponto.

## Questões em aberto

_Nenhuma — decisões fechadas no grilling._
