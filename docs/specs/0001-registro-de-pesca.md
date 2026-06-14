# Spec 0001 — Registro de pesca (catch record)

- **Status:** Proposto
- **Data:** 2026-06-14
- **Relacionado:** [ADR-0001 (PostGIS)](../adr/0001-pontos-de-pesca-postgis.md), [ADR-0002 (privacidade do local)](../adr/0002-privacidade-do-local-de-pesca.md), [Plano 0001 (water bodies + seed OSM)](../plans/0001-pontos-de-pesca-seed-osm.md)

## Problema

Usuários querem **registrar suas pescas**: o que pescaram, onde, quando e em
quais condições. Cada registro fica ligado a uma localização no mapa e a uma
espécie conhecida da região, com fotos e detalhes do peixe e do clima.

## Conceitos (e como se relacionam)

Há **dois** conceitos geográficos — não confundir:

1. **`water_body` (corpo d'água)** — camada de **referência**, populada por seed
   do OpenStreetMap (rios, lagos, lagoas, açudes, represas do RS). Ver
   [Plano 0001](../plans/0001-pontos-de-pesca-seed-osm.md). *(Era `fishing_spot`
   no plano original — renomeado para evitar ambiguidade com "registro de pesca".)*
2. **`catch_record` (registro de pesca / "uma pesca")** — **evento do usuário**.
   Sempre referencia um `water_body` e tem um ponto exato marcado no mapa.

```
usuario ──< catch_record >── water_body (rio/lago do seed)
                 │
                 ├── species  ──▶ fish (catálogo / seed de espécies do RS)
                 ├── weather  (automático via Open-Meteo)
                 └── photos[] (1..N)
```

## Decisões de produto (fechadas)

| Tema | Decisão |
|---|---|
| Cardinalidade | **1 peixe por registro.** Pescaria com N peixes = N registros. |
| Clima | **Automático via API** (Open-Meteo, gratuito, sem chave) por lat/lon + horário. |
| Espécie | **Só da seed.** FK obrigatória para `fish`. Sem texto livre. |
| Localização | **Sempre** marca no mapa. Usuário escolhe expor o **ponto exato** ou só o **rio** (ver ADR-0002). |
| Finalidade | `SPORT` (esportiva) ou `CONSUMPTION` (consumo). |

## Modelo de dados

### `catch_record`
| Campo | Tipo | Notas |
|---|---|---|
| `id` | BIGINT PK | |
| `user_id` | FK → `usuario` | dono do registro, NOT NULL |
| `water_body_id` | FK → `water_body` | rio/lago, NOT NULL (sempre marcado) |
| `location` | `geometry(Point,4326)` | ponto exato marcado no mapa, NOT NULL |
| `location_visibility` | enum | `EXACT` \| `RIVER_ONLY` (ver ADR-0002) |
| `species_id` | FK → `fish` | NOT NULL (só da seed) |
| `weight_grams` | INT | opcional |
| `length_mm` | INT | opcional |
| `description` | TEXT | opcional — detalhes do peixe |
| `fishing_method` | enum | método de pescaria (ver enums) |
| `purpose` | enum | `SPORT` \| `CONSUMPTION`, NOT NULL — ver semântica nos enums |
| `caught_at` | TIMESTAMPTZ | momento da pesca (usado p/ buscar clima), NOT NULL |
| `created_at` / `updated_at` | TIMESTAMPTZ | auditoria |

**Clima embutido (1:1, preenchido automaticamente, todos nullable):**
`weather_temperature_c`, `weather_condition` (enum), `weather_wind_speed_kmh`,
`weather_wind_direction_deg`, `weather_humidity_pct`, `weather_pressure_hpa`,
`weather_code` (código WMO bruto), `weather_captured_at`,
`weather_source` (default `OPEN_METEO`).
> Falha na API de clima **não** bloqueia o registro — campos ficam nulos.

### `catch_photo` (1:N)
| Campo | Tipo | Notas |
|---|---|---|
| `id` | BIGINT PK | |
| `catch_record_id` | FK → `catch_record` | NOT NULL, `ON DELETE CASCADE` |
| `file_path` | VARCHAR | caminho **relativo** no filesystem local, NOT NULL |
| `position` | INT | ordenação |
| `created_at` | TIMESTAMPTZ | |

**Armazenamento (decidido): filesystem local.**
- Arquivos salvos em um diretório configurável (ex.: `app.uploads.dir`), fora de
  `src/` e do controle de versão (`.gitignore`).
- Banco guarda só o **caminho relativo** (`file_path`), nunca o binário.
- Servidos por um endpoint estático/`ResourceHandler` (ex.: `/uploads/**`).
- Nomear arquivos com UUID (evita colisão e *path traversal*); validar
  tipo/tamanho no upload.

### Enums
- **`LocationVisibility`**: `EXACT`, `RIVER_ONLY`.
- **`FishingPurpose`**: `SPORT` \| `CONSUMPTION`. **Unifica finalidade + destino do
  peixe** (campo `released` foi descartado): `SPORT` = pesca esportiva, peixe
  **devolvido à água** (pesca-e-solta); `CONSUMPTION` = peixe **retirado** para
  consumo.
- **`FishingMethod`** (conjunto inicial, extensível): `ARREMESSO`, `FLY`,
  `CORRICO`, `FUNDO`, `BOIA`, `OUTRO`.
- **`WeatherCondition`** (derivado do código WMO do Open-Meteo): `CLEAR`,
  `PARTLY_CLOUDY`, `CLOUDY`, `FOG`, `DRIZZLE`, `RAIN`, `SNOW`, `THUNDERSTORM`.

## Privacidade do local (resumo — detalhe no ADR-0002)

- `EXACT`: ponto exato é público.
- `RIVER_ONLY`: ponto exato é **privado**. Para outros usuários, a API expõe
  apenas o `water_body` (nome + centroide/geometria), nunca o `location`.
- O **dono sempre** vê o próprio ponto exato.
- Regra aplicada na **camada de DTO/serialização**, não só na UI — o `location`
  não pode vazar no JSON para quem não é dono quando `RIVER_ONLY`.

## Clima — integração Open-Meteo

- API gratuita, sem chave. Por `lat/lon` + `caught_at`.
- Endpoint **forecast** para datas recentes; **archive** para histórico.
- Preenchido no backend ao criar o registro (best-effort, assíncrono ou inline).
- Mapear `weather_code` (WMO) → `WeatherCondition` simplificado.

## Espécies — seed do RS (lista plana)

**Decisão:** sem filtro fino. Como o app é focado no RS, "espécies da região" =
todas as espécies do seed. O seletor lista tudo.

- Reaproveita o catálogo `fish` (já existe). A seleção é uma FK para `fish`.
- Requer um **seed de espécies conhecidas do RS** (traíra, dourado, jundiá,
  tilápia, tainha, corvina, pintado, grumatã, lambari, black bass, carpa, etc.).
  → vira um plano próprio.
- O picker de espécie no app consome `/api/fish` (lista paginada simples).
- **Evolução futura (não agora):** filtrar por ambiente usando o `FishType` já
  existente (água doce/salobra/salgada) vs. o corpo d'água — exigiria classificar
  a salinidade dos `water_body`.

## Endpoints (rascunho)

| Método | Rota | Descrição |
|---|---|---|
| `POST` | `/api/catches` | cria registro (autenticado) |
| `POST` | `/api/catches/{id}/photos` | upload de fotos |
| `GET` | `/api/catches` | lista pública (respeita privacidade; filtros: bbox, espécie) |
| `GET` | `/api/catches/{id}` | detalhe (respeita privacidade) |
| `GET` | `/api/catches/mine` | registros do usuário logado |
| `DELETE` | `/api/catches/{id}` | remove (apenas dono) |

## Integração no app (visão)

- Fluxo de criação: marcar ponto no mapa → escolher visibilidade (exato/rio) →
  selecionar espécie (da seed) → peso/comprimento/descrição → método + finalidade
  → fotos → salvar (clima vem automático).
- No mapa: marcadores de pescas. `RIVER_ONLY` aparece sobre o corpo d'água
  (centroide), sinalizado como aproximado.

## Dependências e ordem

1. **Plano 0001** (water_body + seed OSM) — pré-requisito (FK `water_body_id`).
2. Seed de espécies do RS (plano a criar).
3. Esta feature (`catch_record`, fotos, clima, endpoints, app).

## Critérios de aceite

- [ ] Usuário cria um registro marcando ponto no mapa + corpo d'água.
- [ ] Pode ocultar o ponto exato deixando público só o rio (e isso é respeitado no JSON).
- [ ] Espécie selecionada da seed (FK obrigatória).
- [ ] Peso, comprimento, descrição, método e finalidade salvos.
- [ ] Fotos anexadas (1..N).
- [ ] Clima preenchido automaticamente (ou nulo, sem quebrar, se a API falhar).

## Questões em aberto

_Nenhuma — todas as decisões de produto estão fechadas._
