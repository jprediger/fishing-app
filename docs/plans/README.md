# Planos de implementação

Passo a passo de features/refactors **antes** de codar. Cada plano descreve o
diagnóstico, as etapas, a ordem de execução e os critérios de aceite — para que a
implementação (humana ou IA) seja só seguir o roteiro.

## Convenções

- Numeração sequencial: `000X-titulo-curto.md`.
- Topo do arquivo declara **Status**: Proposto → Em andamento → Implementado.
- Decisões arquiteturais saem do plano e viram um [ADR](../adr/).

## Índice

Planos concluídos ficam em `done/`; os pendentes, em `todo/`.

| # | Título | Status |
|---|---|---|
| [0001](./done/0001-pontos-de-pesca-seed-osm.md) | Corpos d'água (`water_body`, PostGIS) + seed de rios/águas do RS via OSM | Implementado |
| [0002](./done/0002-autenticacao-frontend-flutter.md) | Autenticação no frontend (Flutter): login/registro, sessão e HTTP autenticado | Implementado |
| [0003](./done/0003-seed-especies-rs.md) | Seed de espécies de peixes do RS | Implementado |
| [0004](./todo/0004-registro-de-pesca.md) | Registro de pesca (`catch_record`): backend, clima, fotos e app | Proposto |
| [0005](./done/0005-nearest-marcar-ponto-e-mapa-real.md) | Corpo d'água mais próximo (`nearest`), marcar ponto, mapa em dados reais e desempenho de viewport | Implementado |
