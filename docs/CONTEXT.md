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
  Acesso ao backend via `services/` (HTTP). A URL base vem de `ApiConfig`
  e aponta para `localhost:8081` por padrão, com `10.0.2.2:8081` no emulador
  Android.

## Estado atual (atualizar conforme evolui)

- **Espécies (`Fish`)**: catálogo CRUD funcionando, consumido pelo app via
  `GET /api/fish` (paginado).
- **Corpos d'água (`water_body`)**: implementados no backend com PostGIS,
  endpoint `/api/water-bodies` e seed OSM via Overpass. O mapa do app já
  consome o backend e não usa mais pontos *hardcoded*. O seed roda por comando
  próprio (`./gradlew seed`). → ver [plano 0001](./plans/0001-pontos-de-pesca-seed-osm.md).
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
| **Descoberta por espécie** | Fluxo em que o usuário entra por uma **Espécie** e explora **Corpos d'água** ou **Registros de pesca** associados a ela. |
| **Agrupamento por corpo d'água** | Projeção que resume **Registros de pesca** de uma **Espécie** por **WaterBody**, incluindo volume e recência. |
| **FishType** | Classificação da água da espécie: `FRESHWATER`, `SALTWATER`, `BRACKISH`. |
| **Corpo d'água / WaterBody** | Camada de referência geográfica (rio, lago, lagoa, açude, represa) populada por seed do OSM. A ser modelado. |
| **WaterType** | Tipo de corpo d'água: `RIVER`, `LAKE`, `LAGOON`, `RESERVOIR`, `POND`. |
| **Registro de pesca / CatchRecord** | Evento do usuário: 1 peixe pescado, ligado a um corpo d'água + ponto no mapa, com fotos, detalhes e clima. |
| **Estabelecimento / Establishment** | Ponto de interesse de pesca (loja, pesqueiro, marina, rampa etc.) que pode ser associado opcionalmente pelo usuário a um registro de pesca quando a pesca ocorreu naquele estabelecimento ou em seu entorno imediato, sem substituir o corpo d'água. |
| **LocationVisibility** | Privacidade do ponto: `EXACT` (público) \| `RIVER_ONLY` (só o rio é público). Ver [ADR-0002](./adr/0002-privacidade-do-local-de-pesca.md). |
| **FishingMethod** | Método de pescaria: `ARREMESSO`, `FLY`, `CORRICO`, `FUNDO`, `BOIA`, `OUTRO`. |
| **FishingPurpose** | Finalidade: `SPORT` (esportiva) \| `CONSUMPTION` (consumo). |
| **Produto** | Item de loja/marketplace (iscas, equipamentos). |
| **OSM** | OpenStreetMap — fonte de tiles do mapa e de dados de hidrografia. |
| **Overpass API** | API de consulta de dados do OSM (usada para o seed de corpos d'água). |
| **Open-Meteo** | API gratuita de clima — preenche o tempo do registro por lat/lon + horário. |

## Relações de domínio

- Um **CatchRecord** pertence a exatamente um **WaterBody**
- Um **CatchRecord** pode ser associado a zero ou um **Establishment**, sempre por escolha explícita do usuário
- A navegação de descoberta por **Espécie** pode listar **Corpos d'água** ou **Registros de pesca** dessa espécie
- A **Descoberta por espécie** começa por uma **Espécie** e abre uma tela com resumo da espécie e resultados abaixo
- A aba **Espécies** começa com uma lista pesquisável de **Espécies**; tocar em uma espécie abre a **Descoberta por espécie**
- Na lista raiz de **Espécies**, o sinal de atividade principal é a quantidade de **Corpos d'água** com **Registros de pesca** daquela espécie
- A lista raiz de **Espécies** mantém ordenação alfabética por padrão; atividade não redefine o ranking
- Na lista raiz de **Espécies**, espécies sem atividade aparecem com um estado textual explícito, como `Sem registros ainda`
- Um **CatchRecord** com **LocationVisibility = RIVER_ONLY** continua elegível para descoberta por **Espécie** e para agrupamento por **WaterBody**; apenas o ponto exato permanece oculto
- A **Descoberta por espécie** pode abrir o **Mapa** com contexto da espécie selecionada, inclusive quando ainda não existirem **Registros de pesca**
- O botão `Ver no mapa` na **Descoberta por espécie** pode servir só para centralizar um **WaterBody**, sem aplicar filtro visual de **Espécie** no **Mapa**
- O drill-down de um **WaterBody** dentro da **Descoberta por espécie** mostra apenas **Registros de pesca** da **Espécie** selecionada
- No drill-down **Espécie → WaterBody → Registros**, o título principal é o **WaterBody** e o contexto secundário explicita a **Espécie** e a quantidade filtrada de **Registros de pesca**
- O modo padrão da **Descoberta por espécie** depende de **Agrupamento por corpo d'água** servido pelo backend, não calculado no app
- A proximidade entre **CatchRecord** e **Establishment** serve para sugestão durante a criação, não para definir pertencimento
- A associação entre **CatchRecord** e **Establishment** só é permitida quando o ponto da pesca está dentro de um raio curto do estabelecimento
- Só **Establishments** das categorias **PESQUEIRO** e **CLUBE** podem receber associação explícita de um **CatchRecord**
- Durante a criação, o app só oferece para associação os **Establishments** elegíveis que já estejam dentro do raio permitido
- O raio permitido para associar **CatchRecord** a **Establishment** é definido no backend e exibido pelo app ao usuário
- O valor inicial desse raio permitido é **200 m**
- **Establishments** de categorias não associáveis continuam visíveis como pontos de interesse, mas não exibem ações de criar registro ou ver registros associados
- Em um **Establishment** associável, visitantes veem apenas **CatchRecords** públicos associados; o dono continua vendo os próprios registros associados conforme as regras gerais de privacidade
- A associação entre **CatchRecord** e **Establishment** pode ser adicionada, trocada ou removida em edição, desde que continue respeitando categoria elegível e raio permitido
- Nesta fase, o ponto de um **CatchRecord** não é editável após a criação
- Ao iniciar a criação por um **Establishment** associável, o app entra em modo de marcar ponto no mapa já centrado nesse estabelecimento e com a associação pré-marcada
- Se o ponto marcado sair do raio permitido do **Establishment** pré-marcado, o app mantém o estabelecimento visível, porém desmarcado e indisponível até o ponto voltar ao raio

## Exemplo de diálogo

> **Dev:** "Na aba de **Espécies**, o usuário vai ver aparições de traíra?"
> **Especialista de domínio:** "Não usamos 'aparições'. O usuário escolhe uma **Espécie** e então vê **Registros de pesca** dessa espécie, cada um ligado a um **Corpo d'água**."

## Ambiguidades sinalizadas

- "aparição" foi usado para significar **Registro de pesca**; resolução: usar **Registro de pesca** quando o app mostrar capturas publicadas por usuários
- "próximas" foi usado para sugerir proximidade geográfica; resolução: nesta fase, a descoberta por **Espécie** não depende da localização do usuário nem de distância real

## Comandos essenciais

```bash
# Banco (dev)
cd backend && docker compose up -d

# Backend
cd backend && ./gradlew bootRun

# App
cd app && flutter run
# App apontando para outro backend
cd app && flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8081
```
