# Contexto do Projeto — Fishing App

> Documento de entrada. Leia antes de qualquer tarefa. Mantenha curto e atual.

## O que é

Aplicativo de pesca: catálogo de espécies, mapa de pontos de pesca e (em
evolução) recursos de comunidade/produtos. Projeto acadêmico (Univates).

## Arquitetura (alto nível)

```
app/        Flutter (mobile)  ──HTTP──▶  backend/  Spring Boot ──▶ PostgreSQL
```

- **`backend/`** — Spring Boot (Java), Gradle. Persistência via JPA/Hibernate,
  migrations com **Flyway**, banco **PostgreSQL**. Auth com OAuth2 resource
  server + JWT (`security/`). API documentada via OpenAPI/Scalar.
- **`app/`** — Flutter. Mapa com `flutter_map` + tiles do OpenStreetMap.
  Acesso ao backend via `services/` (HTTP). Tem **modo mock** (`USE_MOCK`,
  default `true`) para rodar sem backend.

## Estado atual (atualizar conforme evolui)

- **Espécies (`Fish`)**: catálogo CRUD funcionando, consumido pelo app via
  `GET /api/fish` (paginado).
- **Corpos d'água (`water_body`)**: implementados no backend com PostGIS,
  endpoint `/api/water-bodies` e seed OSM via Overpass. O mapa do app já
  consome o backend e não usa mais pontos *hardcoded*. → ver
  [plano 0001](./plans/0001-pontos-de-pesca-seed-osm.md).
- **Registro de pesca (`catch_record`)**: feature central planejada — usuário
  registra uma pesca (espécie, fotos, peso/comprimento, método, finalidade,
  clima automático) ligada a um corpo d'água e a um ponto no mapa, com opção de
  ocultar o ponto exato. → ver [spec 0001](./specs/0001-registro-de-pesca.md).
- **Usuários/Auth**: em desenvolvimento (`Usuario`, `AuthController`).

### Dívidas técnicas conhecidas

- **Conflito de migration Flyway**: já resolvido. Só existe `V2__create_users.sql`.

## Glossário de domínio

| Termo | Significado |
|---|---|
| **Fish / Espécie** | Espécie de peixe no catálogo (não é um peixe individual). |
| **FishType** | Classificação da água da espécie: `FRESHWATER`, `SALTWATER`, `BRACKISH`. |
| **Corpo d'água / WaterBody** | Camada de referência geográfica (rio, lago, lagoa, açude, represa) populada por seed do OSM. A ser modelado. |
| **WaterType** | Tipo de corpo d'água: `RIVER`, `LAKE`, `LAGOON`, `RESERVOIR`, `POND`. |
| **Registro de pesca / CatchRecord** | Evento do usuário: 1 peixe pescado, ligado a um corpo d'água + ponto no mapa, com fotos, detalhes e clima. |
| **LocationVisibility** | Privacidade do ponto: `EXACT` (público) \| `RIVER_ONLY` (só o rio é público). Ver [ADR-0002](./adr/0002-privacidade-do-local-de-pesca.md). |
| **FishingMethod** | Método de pescaria: `ARREMESSO`, `FLY`, `CORRICO`, `FUNDO`, `BOIA`, `OUTRO`. |
| **FishingPurpose** | Finalidade: `SPORT` (esportiva) \| `CONSUMPTION` (consumo). |
| **Produto** | Item de loja/marketplace (iscas, equipamentos). |
| **OSM** | OpenStreetMap — fonte de tiles do mapa e de dados de hidrografia. |
| **Overpass API** | API de consulta de dados do OSM (usada para o seed de corpos d'água). |
| **Open-Meteo** | API gratuita de clima — preenche o tempo do registro por lat/lon + horário. |

## Comandos essenciais

```bash
# Banco (dev)
cd backend && docker compose up -d

# Backend
cd backend && ./gradlew bootRun

# App (modo mock, default)
cd app && flutter run
# App apontando para backend real
cd app && flutter run --dart-define=USE_MOCK=false
```
