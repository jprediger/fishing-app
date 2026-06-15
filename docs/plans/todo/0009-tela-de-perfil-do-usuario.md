# Plano 0009 — Tela de perfil do usuário (próprio + de outros)

- **Status:** Proposto
- **Data:** 2026-06-15
- **Relacionado:** [Spec 0001 (registro de pesca)](../../specs/0001-registro-de-pesca.md),
  [Plano 0002 (auth frontend)](../done/0002-autenticacao-frontend-flutter.md),
  [Plano 0004 (registro de pesca)](../done/0004-registro-de-pesca.md),
  [Plano 0007 (pescas no mapa)](../done/0007-pescas-no-mapa.md),
  [Plano 0008 (feed de registros)](../done/0008-feed-de-registros-do-corpo-dagua.md)

## Objetivo

Transformar a `ProfileScreen` numa tela **única e parametrizada por usuário**,
que serve tanto o **próprio perfil** quanto o **perfil de outra pessoa**, com:

- **Foto de perfil** (avatar) real, com upload reaproveitando a infra de fotos.
- **Badges/stats** reais (substituindo os 3 cards mockados): **Capturas**,
  **Espécies** e **Corpos d'água**, agregadas no backend.
- **Posts (registros de pesca)** da pessoa em **feed com scroll infinito**,
  abaixo das informações iniciais, **reusando o `_CatchPostCard` do Plano 0008**.

É a peça que **0007 e 0008 deixaram explicitamente adiada**: a navegação
"tocar autor → abrir o perfil daquele usuário".

> **Dependências (ambas ✅ ENTREGUES):** **0007** entregou `AuthorDTO {id, name}`
> no `CatchResponseDTO` e `CatchAuthor`/`author` no app. **0008** entregou o
> `CatchFeedScreen` com scroll infinito e os widgets `_CatchPostCard`/`_Thumbnail`/
> `_MiniPill`/`_FeedStateCard`. **Atenção:** esses widgets são **privados** ao
> `catch_feed_screen.dart` e o **autor não é clicável** em lugar nenhum — reusá-los
> no perfil exige **extração** para um arquivo compartilhado (ver Etapas).

## Diagnóstico (situação atual)

- **`app/lib/screens/profile_screen.dart`** — tela "Eu" só do próprio usuário,
  alimentada pelo `AuthController`. As "badges mockadas" são os 3 `_StatCard`
  (**Capturas / Pontos / Saídas**, todos `'0'` hardcoded). Tem ainda seções
  "Atividade" (*Histórico de pescarias*, *Pontos salvos* — mock/sem backend) e
  "Conta" (*Editar perfil*, *Sair*). Header com `CircleAvatar` de ícone fixo
  (`Icons.person`), sem foto.
- **`HomeShell`** monta `ProfileScreen(auth: widget.auth)` na aba "Eu".
- **Backend `User`** — sem campo de avatar. **`UserResponseDTO`** expõe e-mail
  (ok só no `/me`). Único endpoint de usuário: `GET/PUT /api/users/me`
  (`MeController`). **Não há** `GET /api/users/{id}`.
- **`CatchResponseDTO`** (✅ 0007) já tem `AuthorDTO author {id, name}` (sem
  e-mail). DTO `AuthorDTO` existe em `dto/AuthorDTO.java`.
- **`CatchController#findAll`** (✅ 0008) já tem
  `findAll(pageable, email, speciesId, bbox, waterBodyId)`; o feed do corpo
  d'água usa `findByWaterBody_Id` com `Sort createdAt DESC`. **Não há** filtro por
  usuário (`userId`).
- **`CatchService`** (app) tem `list({bbox, speciesId})`, `mine`,
  `listByWaterBody({waterBodyId, page, size})` (com `sort=createdAt,desc`,
  retorna `List<CatchRecord>` e infere "tem mais" por `page.length == size`),
  `fetchById`, `uploadUrl(...)`. **Não** filtra por usuário.
- **`models/catch_record.dart`** (✅ 0007) já tem `CatchAuthor {int id, String name}`
  e o campo `author` (nullable defensivo).
- **`screens/catch_feed_screen.dart`** (✅ 0008) tem a máquina de **scroll
  infinito** completa e os widgets **`_CatchPostCard`** (com `_Thumbnail`,
  `_MiniPill`, `_FeedStateCard`). **Todos privados** ao arquivo. O card mostra o
  autor como **texto puro** (`record.mine ? 'Você' : author?.name`) — **não é
  clicável** e não há `onAuthorTap`.
- **`CatchDetailScreen`** já existe e é o destino ao tocar um post; **não exibe o
  autor de forma alguma** (zero referência a `author`). Passará a exibir, com o
  autor clicável.
- **Storage de fotos** — `CatchPhotoStorageService.store(MultipartFile)` é
  genérico (valida tipo/tamanho, devolve `filename`); servido por `/uploads/**`
  (`UploadConfig`), **autenticado** (`SecurityConfig`), consumido no app com
  `Authorization: Bearer` (ver `catch_detail_screen`/`_Thumbnail`). Reaproveitável
  pro avatar **sem mudanças**.

## Decisões fechadas (grilling)

| Tema | Decisão |
|---|---|
| Escopo deste documento | 0007 e 0008 **já entregues** → este plano está **pronto para implementar**. |
| Tela própria vs. de outros | **Tela única** `ProfileScreen`, parametrizada por `userId`. O app decide "próprio" comparando o `userId` visto com `auth.user.id`. |
| Foto de perfil | **Upload completo**, reusando a infra de fotos (`CatchPhotoStorageService` + `/uploads/**`). Campo `avatarPath` no `User`; upload em `POST /api/users/me/avatar`; troca de foto na tela de edição. |
| Badges/stats | Substituir os 3 mocks por **Capturas + Espécies + Corpos d'água**, **agregadas no backend** (a lista é paginada; não dá pra somar no app). "Saídas"/"Pontos salvos"/"Histórico" **saem**. |
| Endpoint de posts | **`GET /api/catches?userId=X`** (estende o `findAll` existente), `createdAt desc`, paginado, **scroll infinito**. Unifica próprio e outros. `/api/catches/mine` continua existindo, mas o perfil não usa. |
| Endpoint do header | **Novo `GET /api/users/{id}` público** → `UserProfileDTO {id, name, avatarPath, role, memberSince, catchCount, speciesCount, waterBodyCount}`. **Sem e-mail** (consistente com 0007). `/api/users/me` segue para edição. |
| Layout dos posts | Feed reusando o card do 0008, filtrado por usuário. Como o `_CatchPostCard` é **privado**, **extrair** para `widgets/catch_post_card.dart` (público) e o `CatchFeedScreen` passa a importá-lo. No perfil a **linha de autor é omitida** (`showAuthor: false`). Tocar → `CatchDetailScreen`. |
| Scroll | **Uma superfície só** (`CustomScrollView`/slivers): header → stats → posts rolam juntos; paginação ao aproximar do fim. |
| Ações do próprio perfil | Tiles "Atividade" e "Conta" **removidas**. **Editar perfil** e **Sair** viram ações no **AppBar**, visíveis **só no próprio** perfil. |
| Pontos de entrada | Autor **clicável** (greenfield: 0008 deixou como texto puro) no **card extraído** (feed) **e** no **`CatchDetailScreen`** (que passa a exibir o autor) → `ProfileScreen(userId)`. Card ganha `onAuthorTap` opcional. |
| Privacidade | Perfil é público (todo registro é público; ver 0007). **Nunca** expor e-mail de terceiros. Privacidade do **ponto** já tratada no `CatchService.toDto`. `role` é exposto no perfil (para a badge de admin). |

## Etapas

### Backend

1. **Migration Flyway** (`V3__add_user_avatar.sql` — confirmar o próximo número):
   `ALTER TABLE users ADD COLUMN avatar_path VARCHAR(255);` (nullable).

2. **`User`** — novo campo `String avatarPath` (nullable).

3. **`UserResponseDTO`** (usado pelo `/me`) — incluir `avatarPath` (mantém
   e-mail, pois é o próprio usuário). Atualizar `from(User)`.

4. **`UserProfileDTO`** (novo, público) —
   `record UserProfileDTO(Long id, String name, String avatarPath, Role role,
   OffsetDateTime memberSince, long catchCount, long speciesCount,
   long waterBodyCount)`. **Sem e-mail.**

5. **Stats agregadas** — no `CatchRepository` (ou `UserRepository`), uma projeção
   por usuário:
   `SELECT COUNT(*), COUNT(DISTINCT species_id), COUNT(DISTINCT water_body_id)
   FROM catch_record WHERE user_id = :userId`. Mapear para os 3 campos do DTO.

6. **`UserController`** (novo) — `GET /api/users/{id}` → `UserProfileDTO`
   (404 se inexistente/inativo). Autenticado (já coberto por `GET /api/** authenticated`).
   - **`UserService#getProfile(Long id)`** carrega o `User` + as 3 stats.

7. **Upload de avatar** — `POST /api/users/me/avatar` (multipart, 1 arquivo) em
   `MeController` (ou `UserController`):
   - `MeService`/novo método: reusa `CatchPhotoStorageService.store(file)`;
     **apaga o avatar anterior** (`storageService.delete(old)`) se houver; grava
     `avatarPath` no `User`; retorna o `UserResponseDTO` atualizado.
   - (Opcional) `DELETE /api/users/me/avatar` para remover a foto.

8. **`CatchController#findAll`** — novo `@RequestParam(required=false) Long userId`,
   repassado à sobrecarga de `CatchService.findAll(...)`.
   - **`CatchService.findAll`** — hoje a assinatura "completa" é
     `findAll(pageable, requesterEmail, speciesId, bbox, waterBodyId)`. Acrescentar
     `userId` (nullable). Quando presente, listar por `user_id` com
     `Sort createdAt DESC` (mesmo padrão já usado para `waterBodyId`), via novo
     `CatchRepository.findByUser_Id(Long userId, Pageable pageable)`. A
     privacidade do ponto continua via `toDto`.
   - Manter as sobrecargas existentes (mapa/`bbox` usam a de 4 args) intactas.

9. **Testes (backend)**:
   - `UserControllerTest`/`UserServiceTest`: `GET /api/users/{id}` traz nome,
     avatar, role, memberSince e as 3 stats corretas; **nunca** e-mail; 404 p/ id
     inexistente.
   - Stats: contagens distintas corretas (mesma espécie/corpo d'água não duplica).
   - Avatar: upload grava `avatarPath`, substitui apaga o anterior, valida tipo
     (reuso da validação do storage), só o próprio (`/me`).
   - `CatchControllerTest`: `?userId=X` retorna só as pescas daquele usuário,
     `createdAt desc`, paginado, respeitando privacidade do ponto.

### Front (`app/`)

10. **`models/auth_user.dart`** — campo `String? avatarPath` em `AuthUser`
    (parse de `json['avatarPath']`), pra sessão/`/me` exibirem o avatar.

11. **`models/user_profile.dart`** (novo) — `UserProfile {int id, String name,
    String? avatarPath, UserRole role, DateTime? memberSince, int catchCount,
    int speciesCount, int waterBodyCount}` + `fromJson`.

12. **Serviço de perfil** — `GET /api/users/{id}` (novo `UserService`/
    `ProfileService`, ou método em `auth_service`) → `UserProfile`. Avatar exibido
    com `catchService.uploadUrl(avatarPath)` + header `Authorization: Bearer`
    (mesmo padrão das fotos de pesca).

13. **Extrair o card para `widgets/catch_post_card.dart`** — mover `_CatchPostCard`
    (e os helpers `_Thumbnail`/`_MiniPill`, e provavelmente `_FeedStateCard`) de
    `catch_feed_screen.dart` para um arquivo **público** reusável:
    - `CatchPostCard` ganha 2 parâmetros novos: **`bool showAuthor = true`**
      (perfil passa `false`) e **`VoidCallback? onAuthorTap`** (clique no nome/avatar
      do autor → abre o perfil; null = não clicável).
    - `CatchFeedScreen` passa a **importar** o card extraído (sem mudar comportamento;
      no feed `showAuthor: true`, `onAuthorTap` abre `ProfileScreen(author.id)`).

14. **`CatchService.listByUser`** — novo método espelhando `listByWaterBody`:
    `listByUser({required int userId, int page, int size})` →
    `GET /api/catches?userId=X&sort=createdAt,desc`, retornando `List<CatchRecord>`
    (mesma inferência de "tem mais" por tamanho da página).

15. **`ProfileScreen` (reescrita)** — vira parametrizada:
    `ProfileScreen({int? userId, AuthController? auth})`.
    - `userId == null` ou `== auth.user.id` ⇒ **próprio perfil**.
    - **Layout** em `CustomScrollView` (reaproveitar a **máquina de scroll
      infinito** do `CatchFeedScreen`: `ScrollController` + `_maybeLoadMore`,
      estados `_loading/_loadingMore/_hasMore/_error/_loadMoreError`):
      1. **Header** (sliver): avatar (foto via `uploadUrl(avatarPath)` + Bearer, ou
         iniciais/ícone fallback), nome, badge de role (admin),
         "Pescando desde {memberSince}".
      2. **Stats** (sliver): 3 cards — Capturas / Espécies / Corpos d'água
         (do `UserProfile`).
      3. **Posts** (`SliverList`): `CatchPostCard` (extraído) com
         **`showAuthor: false`**, paginados via `CatchService.listByUser(...)`.
         Tocar → `CatchDetailScreen`.
    - **Estados**: carregando, vazio ("Nenhum registro ainda."), erro
      (mensagem + retry) — reusar `_FeedStateCard` extraído.
    - **Próprio perfil**: AppBar com ações **Editar perfil** (→ `EditProfileScreen`)
      e **Sair** (`auth.logout()`). **Perfil de outros**: sem essas ações.
    - Remover `_StatCard` mockados, seções "Atividade"/"Conta" e tiles
      `_ProfileTile` obsoletas.

15. **`HomeShell`** — aba "Eu" monta `ProfileScreen(auth: widget.auth)` (próprio).

16. **`EditProfileScreen`** — adicionar **trocar foto de perfil**: avatar atual +
    botão de selecionar imagem (`image_picker`, já usado), upload via o serviço de
    avatar; atualizar o `AuthController`/sessão com o novo `avatarPath`.

17. **Pontos de entrada (navegação para perfil de outros)**:
    - **`CatchPostCard` extraído (feed)** — passar `onAuthorTap` que abre
      `ProfileScreen(userId: record.author.id, auth: ...)` (no perfil esse card vem
      com `showAuthor: false`, então não navega para si mesmo).
    - **`CatchDetailScreen`** — passar a **exibir o autor** (campo `author` do 0007,
      hoje não renderizado), clicável → mesmo destino. Cuidar do caso `author == null`
      e de não navegar quando `record.mine`.

18. **Testes de widget**:
    - `ProfileScreen` próprio: mostra stats reais, posts, ações Editar/Sair.
    - `ProfileScreen` de outro (`userId` diferente): mostra stats/posts, **sem**
      Editar/Sair.
    - Scroll infinito carrega a próxima página; estado vazio; erro + retry.
    - Tocar autor (no card do feed e no detalhe) abre `ProfileScreen` com o id.

## Ordem de execução

1. Backend: migration + `avatarPath` + `UserProfileDTO` + stats + `GET /api/users/{id}`.
2. Backend: upload de avatar (`POST /api/users/me/avatar`) + `?userId` no `findAll`.
3. Front: modelos (`avatarPath` no `AuthUser`, `UserProfile`) + serviço de perfil
   + `CatchService.listByUser`.
4. Front: **extrair** `CatchPostCard` (+ helpers) para `widgets/` com `showAuthor`/
   `onAuthorTap`; `CatchFeedScreen` passa a importá-lo.
5. Front: reescrita da `ProfileScreen` (header + stats + feed + estados + AppBar).
6. Front: avatar na `EditProfileScreen`.
7. Front: autor clicável no card do feed e no `CatchDetailScreen`.
8. Testes (backend + widget) e `bash scripts/validate.sh`.

## Critérios de aceite

- [ ] `ProfileScreen` única serve **próprio** e **de outros** (decidido por id).
- [ ] Header exibe **foto de perfil** real (fallback iniciais/ícone quando ausente).
- [ ] Usuário consegue **enviar/trocar** a foto de perfil (`POST /api/users/me/avatar`).
- [ ] As 3 badges são **Capturas / Espécies / Corpos d'água**, com valores reais
      **agregados no backend**.
- [ ] `CatchPostCard` extraído para `widgets/` e reusado por `CatchFeedScreen` e
      `ProfileScreen` (feed do corpo d'água segue funcionando igual).
- [ ] Posts da pessoa aparecem em **feed com scroll infinito**, sem a linha de
      autor; tocar abre `CatchDetailScreen`.
- [ ] `GET /api/users/{id}` retorna o perfil público **sem e-mail**.
- [ ] `GET /api/catches?userId=X` lista as capturas do usuário, `createdAt desc`,
      paginado, respeitando a privacidade do ponto.
- [ ] No próprio perfil há **Editar perfil** e **Sair** no AppBar; no de outros, não.
- [ ] Tocar o autor (no card do feed e no `CatchDetailScreen`) abre o perfil dele.
- [ ] Suíte (`bash scripts/validate.sh`) verde.

## Riscos / armadilhas

- **Card privado → extração:** `_CatchPostCard` e helpers vivem dentro de
  `catch_feed_screen.dart`. A extração para `widgets/` não pode regredir o feed do
  corpo d'água (manter os testes de widget do 0008 verdes após mover o código).
- **Autor clicável é greenfield:** 0008 entregou o autor como **texto puro**; não
  existe `onAuthorTap` nem exibição de autor no detalhe. É trabalho novo, não
  "ligar um fio".
- **Avatar autenticado:** `/uploads/**` exige Bearer; o `Image.network` do avatar
  precisa do header (como já é feito no `catch_detail_screen`). Em perfis de
  terceiros o token é o do próprio usuário logado (serving é global, não por dono).
- **Avatar antigo órfão:** ao trocar a foto, **apagar** o arquivo anterior pra não
  acumular lixo em `uploads/`.
- **Privacidade:** `UserProfileDTO` e o card do perfil **nunca** podem vazar
  e-mail de terceiros. River-only de terceiros continua sem ponto exato.
- **Stats vs. paginação:** as contagens **têm** que vir do backend; somar o que
  veio na primeira página dá número errado.
- **Sort em dois lugares:** `createdAt desc` do feed do perfil precisa não brigar
  com o sort default (`id`) do mapa/`bbox` — alinhar com a decisão do 0008.
- **`?userId` combinável:** garantir que `userId` componha com `bbox`/`speciesId`/
  `waterBodyId` sem quebrar os usos existentes do `findAll`.

## Questões em aberto

_Nenhuma — decisões fechadas no grilling._
