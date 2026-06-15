# Plano 0005 — Corpo d'água mais próximo (`nearest`), marcar ponto no mapa, mapa em dados reais e desempenho de viewport

- **Status:** Implementado
- **Data:** 2026-06-14
- **Relacionado:** [Spec 0001 (registro de pesca)](../../specs/0001-registro-de-pesca.md),
  [ADR-0001 (PostGIS)](../../adr/0001-pontos-de-pesca-postgis.md),
  [Plano 0001 (water_body + seed OSM)](./0001-pontos-de-pesca-seed-osm.md),
  [Plano 0004 (registro de pesca)](../todo/0004-registro-de-pesca.md)

> **Estado (2026-06-14):** **Implementado** (verificado: `./gradlew test` e
> `flutter test` OK). Frente A backend (`nearest`) + Frente C backend
> (`zoom`/simplify/limit), Frente B (`mock_data.dart` removido; serviços sem
> `USE_MOCK`; testes reescritos) e Frente A/C front (`map_screen` com viewport
> real, cancelamento, skip por bbox, gate de zoom, pin solto + card ao vivo + CTA
> stub). Teste de integração PostGIS em `WaterBodyRepositoryIntegrationTest`. O
> **ponto de entrada** do Plano 0004 (CTA "Criar registro aqui") já existe como
> stub. *(Mudanças ainda uncommitted no worktree.)*

## Objetivo

Preparar o terreno para o registro de pesca (Plano 0004) **sem ainda persistir
nada**. Três frentes:

- **A) `nearest`** — endpoint que resolve o `water_body` mais próximo de um ponto
  + UX de marcar o ponto no mapa (fluxo "pin solto"). É a peça que o registro
  futuro vai consumir para preencher `water_body_id` e `location`.
- **B) Mapa em dados reais** — remover o mock do app inteiro; tudo passa a falar
  com o backend.
- **C) Desempenho de viewport** — endurecer o carregamento por área do mapa
  (cancelamento, skip, zoom mínimo, simplificação e teto de feições).

**Fora de escopo (fica no Plano 0004):** a tela de formulário do registro,
`catch_record`, fotos, clima, privacidade. Aqui o botão "Criar registro" é um
**stub**.

## Diagnóstico (situação atual)

- **Backend:** `WaterBodyController` só expõe `GET /api/water-bodies?bbox=...`
  (`findInBbox`). Não há consulta "mais próximo". DTO `WaterBodyResponseDTO`
  serializa GeoJSON + centroide.
- **Front:** `map_screen.dart` já carrega por viewport (debounce 350ms em
  `onPositionChanged`) e renderiza `PolylineLayer`/`PolygonLayer`/`MarkerLayer`.
  Porém: **não cancela requisição obsoleta** (race), **refaz fetch a cada gesto**
  mesmo sem sair da área, e **carrega em qualquer zoom** (RS inteiro = milhares de
  feições).
- **Mock:** `services/mock_data.dart` finge o backend inteiro
  (`/api/fish`, `/api/water-bodies`, `/auth/*`, `/api/users/me`) via
  `createMockClient()`. Os 3 services (`fish`, `auth`, `water_body`) têm flag
  `useMock` (default `true`). Apenas `fish_service_test.dart` e
  `water_body_service_test.dart` usam `createMockClient`; os demais testes já
  injetam um `MockClient` próprio.

## Decisões fechadas (grilling)

| Tema | Decisão |
|---|---|
| Escopo | Frentes **A + B + C**; registro (`catch_record`) fica para o Plano 0004. |
| Ponto longe de qualquer água | Backend **bloqueia por raio** (`ST_DWithin`); miss → **404**. |
| Raio | **Configurável**, `app.water-body.nearest-radius-m` (default **5000 m**). Seed é esparso (só água nomeada) → raio generoso evita bloqueio falso. |
| Resposta do `nearest` | **Reusa `WaterBodyResponseDTO`** + campo `distanceMeters` (nullable; `null` no list por bbox). |
| Métrica de distância | **`geography`** (metros reais), não graus. |
| Remoção de mock | **App todo**: tira `useMock`/`createMockClient` de fish, auth e water_body; deleta `mock_data.dart`. Dev passa a exigir backend de pé (login real). |
| Marcar ponto | **Inline na aba do mapa** (sem tela nova). `onTap` solta um **pin arrastável**. |
| Disparo do `nearest` | **Ao vivo, debounced (~400 ms)** em `onTap`/`onDragEnd`. Reusa o cancelamento de obsoletos da frente C. |
| Widget de seleção | **Bottom card que atualiza ao vivo**: nome + tipo do rio, `~Xm`, CTA "Criar registro aqui". Sem água < raio → card vermelho, CTA desabilitado. |
| CTA "Criar registro" | **Stub** neste slice (snackbar/placeholder). Contrato futuro: `Navigator.push(FormRegistro(point, waterBody))`. |
| Simplificação de geometria | Front manda **`&zoom=N`**; backend mapeia **zoom → tolerância** e aplica `ST_SimplifyPreserveTopology`. |
| Zoom aberto | **Gate de zoom mínimo (~9)**: abaixo, front não busca e mostra "Aproxime para ver os rios". **`LIMIT`** (default 500) como rede de segurança. |

## Etapas

### Frente A — `nearest` (backend)

1. **`WaterBodyRepository.findNearest`** (nativeQuery), mesmas colunas do
   `findInBbox` + `distanceMeters`:
   ```sql
   SELECT id, name, water_type AS waterType,
          ST_AsGeoJSON(geom) AS geomGeoJson,
          osm_id AS osmId, source,
          ST_X(ST_Centroid(geom)) AS centerLon,
          ST_Y(ST_Centroid(geom)) AS centerLat,
          ST_Distance(geom::geography, ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography) AS distanceMeters,
          created_at AS createdAt, updated_at AS updatedAt
   FROM water_body
   WHERE ST_DWithin(
           geom::geography,
           ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography,
           :radiusM)
   ORDER BY geom::geography <-> ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography
   LIMIT 1
   ```
   - `ST_DWithin(geography)` filtra em metros; `<->` (KNN, índice GIST) ordena.
   - Estender a projeção `WaterBodyViewportRow` com `Double getDistanceMeters()`.
2. **`WaterBodyResponseDTO`** — novo campo `Double distanceMeters` (nullable).
   `toDto` do `findInBbox` passa `null`.
3. **`WaterBodyService.findNearest(double lat, double lon)`** → `Optional<WaterBodyResponseDTO>`
   (empty quando o repo não acha). Lê o raio de
   `@Value("${app.water-body.nearest-radius-m:5000}")`.
4. **`WaterBodyController`** — `GET /api/water-bodies/nearest?lat=..&lon=..`:
   `200` com DTO; **`404`** quando vazio; `400` se faltar/inválido `lat`/`lon`.
5. **Security** — sem mudança: cai em `GET /api/** → authenticated`
   (`SecurityConfig:62`).
6. **Testes** — `WaterBodyServiceTest`/`WaterBodyControllerTest` (Testcontainers
   PostGIS): acha o mais próximo dentro do raio; 404 fora do raio; `distanceMeters`
   preenchido.

### Frente A — marcar ponto (front)

7. **`WaterBodyService.fetchNearest({lat, lon})`** → `Future<WaterBody?>`:
   `200` → parse; **`404` → `null`** (sem água perto); outros → `ApiException`.
   `WaterBody` ganha `double? distanceMeters`.
8. **`map_screen.dart`** — modo "marcar ponto" inline:
   - FAB **"+"** entra no modo (esconde o carrossel); botão **"X"** sai.
   - `MapOptions.onTap` define `_draftPoint`; pin **arrastável** (`onDragEnd`).
   - `onTap`/`onDragEnd` → debounce ~400 ms → `fetchNearest`, com o mesmo
     cancelamento de obsoletos da frente C (resposta antiga é descartada).
   - **Bottom card ao vivo**: ícone + nome + tipo + `~Xm` + CTA "Criar registro
     aqui". `null`/sem água < raio → card vermelho "Nenhuma água num raio de 5 km",
     CTA desabilitado.
   - **CTA = stub**: snackbar "Registro em breve" (futuro: push do form com
     `(LatLng, WaterBody)`).
9. **Widget test** do modo marcar (service injetado): pin + card com nome; estado
   "sem água" desabilita o CTA.

### Frente B — remover mock (app todo)

10. Remover `useMock` e o ramo `createMockClient()` de `fish_service.dart`,
    `auth_service.dart`, `water_body_service.dart` (cliente passa a ser sempre
    `http.Client()` real; `client` segue **injetável** para teste).
11. **Deletar `services/mock_data.dart`**.
12. `ApiConfig` já resolve `baseUrl` (Android `10.0.2.2`, demais `localhost`,
    override `--dart-define=API_BASE_URL=...`) — sem mudança.
13. Reescrever **`fish_service_test.dart`** e **`water_body_service_test.dart`**
    para `MockClient` inline (padrão já usado em `widget_test`/`app_e2e`).
14. Nota no `app/README` (ou equivalente): dev agora exige backend no ar (inclui
    login).

### Frente C — desempenho de viewport

**Front (`map_screen.dart`):**
15. **Cancelar obsoletos**: token de sequência incremental; descartar resposta
    cujo token não é o mais recente (evita sobrescrever com dado velho).
16. **Skip por bbox+padding**: buscar um bbox com ~20% de folga e guardar o
    último carregado; se o novo viewport está **contido** nele, não refaz fetch
    (pan pequeno = zero request).
17. **Gate de zoom mínimo (~9)**: abaixo, não busca e exibe "Aproxime para ver os
    rios"; limpa/segura a camada.
18. Enviar **`&zoom=<round(camera.zoom)>`** no fetch por bbox. Debounce 350 ms
    (já existe).

**Backend (`findInBbox` + service + controller):**
19. Novo parâmetro **`zoom`** (opcional; ausente = geometria crua).
20. **`ST_SimplifyPreserveTopology(geom, :tol)`** com tabela zoom → tolerância
    (ex.: `≤8→0.01`, `11→0.001`, `≥14→0`).
21. **`LIMIT :maxFeatures`** — `app.water-body.max-features` (default 500).
22. Manter `ST_Intersects` + índice GIST. Ajustar
    `WaterBodyServiceTest`/`WaterBodyControllerTest` para a nova assinatura.

## Parâmetros configuráveis

| Parâmetro | Default | Onde |
|---|---|---|
| `app.water-body.nearest-radius-m` | 5000 | backend |
| `app.water-body.max-features` | 500 | backend |
| zoom → tolerância (simplify) | `≤8:0.01, 11:0.001, ≥14:0` | backend |
| zoom mínimo de carga | 9 | front |
| padding do bbox | 0.2 (20%) | front |
| debounce viewport / nearest | 350 ms / 400 ms | front |

## Ordem de execução

1. Backend `nearest` (repo + DTO + service + controller + testes).
2. Backend perf do `findInBbox` (`zoom`, simplify, limit + ajuste de testes).
3. Front B: remover mock + reescrever os 2 testes.
4. Front C: cancelamento + skip por bbox + gate de zoom + `&zoom`.
5. Front A: modo marcar + bottom card ao vivo + `fetchNearest` + CTA stub.
6. Widget test do modo marcar.

## Critérios de aceite

- [ ] `GET /api/water-bodies/nearest?lat&lon` devolve o corpo d'água mais próximo
      dentro do raio (com `distanceMeters`) e **404** fora do raio.
- [ ] Raio ajustável por propriedade sem recompilar.
- [ ] Mapa funciona **sem mock** (app fala com o backend real; login real).
- [ ] `mock_data.dart` removido; suíte de testes verde.
- [ ] Marcar ponto solta pin arrastável e o bottom card mostra o rio + distância
      ao vivo; sem água < raio desabilita o CTA.
- [ ] CTA "Criar registro" é stub (sem persistência).
- [ ] Pan pequeno não refaz request; zoom muito aberto não carrega (mostra dica);
      requisição obsoleta nunca sobrescreve a atual.
- [ ] Payload por viewport reduzido por `zoom`/simplify e limitado por `LIMIT`.

## Riscos / armadilhas

- **KNN em `geography`**: `<->` sobre `geography` usa índice no PostGIS 3.4
  (imagem `postgis/postgis:16-3.4`); confirmar plano de execução em volume real.
- **`distanceMeters` no list**: fica `null` — o front deve ignorar nesse caminho.
- **Tabela zoom→tolerância**: calibrar com dados reais do seed (rio muito
  simplificado "engole" curvas; pouco simplificado não alivia o payload).
- **Remoção de mock**: garantir que nenhum teste dependa do `useMock` default
  (os atuais já injetam `client`, exceto os 2 reescritos).
- **Gate de zoom**: `initialZoom` (10.7) > 9, então a carga inicial continua
  ocorrendo.

## Questões em aberto

_Nenhuma — decisões fechadas no grilling acima._
