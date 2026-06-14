# Planos de implementação

Passo a passo de features/refactors **antes** de codar. Cada plano descreve o
diagnóstico, as etapas, a ordem de execução e os critérios de aceite — para que a
implementação (humana ou IA) seja só seguir o roteiro.

## Convenções

- Numeração sequencial: `000X-titulo-curto.md`.
- Topo do arquivo declara **Status**: Proposto → Em andamento → Implementado.
- Decisões arquiteturais saem do plano e viram um [ADR](../adr/).

## Índice

| # | Título | Status |
|---|---|---|
| [0001](./0001-pontos-de-pesca-seed-osm.md) | Corpos d'água (`water_body`, PostGIS) + seed de rios/águas do RS via OSM | Proposto |
| [0002](./0002-autenticacao-frontend-flutter.md) | Autenticação no frontend (Flutter): login/registro, sessão e HTTP autenticado | Proposto |
| [0003](./0003-seed-especies-rs.md) | Seed de espécies de peixes do RS | Proposto |
| [0004](./0004-registro-de-pesca.md) | Registro de pesca (`catch_record`): backend, clima, fotos e app | Proposto |
