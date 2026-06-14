# ADR-0001: Modelar pontos de pesca com PostGIS

- **Status:** Aceito
- **Data:** 2026-06-14
- **Decisores:** equipe Fishing App

## Contexto

O app precisa exibir pontos de pesca (rios, lagos, lagoas, açudes, represas) no
mapa. Hoje não há nada no backend — o mapa usa 3 pontos *hardcoded*. Queremos
popular automaticamente os corpos d'água do Rio Grande do Sul a partir de uma
base de mapas aberta (OpenStreetMap). Rios e massas d'água são **geometrias**
(linhas e polígonos), não pontos simples. O banco já é **PostgreSQL**.

## Decisão

Armazenar os pontos de pesca como **geometria real** usando a extensão
**PostGIS** do PostgreSQL, com mapeamento via **hibernate-spatial** + **JTS** no
backend. As consultas do mapa serão por *bounding box* (viewport) usando índice
espacial GIST.

## Alternativas consideradas

- **Ponto simples (lat/lon em colunas numéricas)** — mais simples e suficiente
  para marcadores, mas perde a fidelidade do traçado de rios/contorno de lagos
  e dificulta evoluções (ex.: distância até a margem). Rejeitado por limitar o
  produto desde o início.
- **Guardar GeoJSON como texto/JSONB** — evita PostGIS, mas perde índice
  espacial e operações geográficas no banco (filtro por viewport viraria scan).
  Rejeitado por performance.

## Consequências

- **Positivas:** consultas espaciais eficientes (GIST), fidelidade geográfica,
  base sólida para features futuras (proximidade, rotas, áreas).
- **Negativas / custos:** imagem Docker do Postgres passa a ser
  `postgis/postgis`; dependências extras no backend; curva de aprendizado de
  PostGIS/JTS.
- **Riscos / mitigações:** `ddl-auto=validate` exige que o tipo `geometry` no
  schema bata com a entidade — validar com testcontainers (já há
  `testcontainers-postgresql`, trocar para imagem PostGIS nos testes).
