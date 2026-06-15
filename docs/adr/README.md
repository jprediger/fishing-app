# Architecture Decision Records (ADR)

Registro de **decisões técnicas relevantes**: o contexto, a decisão tomada e
suas consequências. Servem para que ninguém (humano ou IA) precise reabrir uma
discussão já resolvida — e, quando precisar, saiba *por que* foi decidido assim.

## Regras

- Um ADR por decisão. Numeração sequencial: `000X-titulo.md`.
- Após **Aceito**, o ADR é **imutável**. Mudou? Crie um novo que o substitui
  (`Status: Substituído por ADR-000Y`).
- Use o [template](./template.md).

## Índice

| # | Título | Status |
|---|---|---|
| [0001](./0001-pontos-de-pesca-postgis.md) | Modelar pontos de pesca com PostGIS | Aceito |
| [0002](./0002-privacidade-do-local-de-pesca.md) | Privacidade do local de pesca | Aceito |
| [0003](./0003-associacao-opcional-de-catch-record-a-establishment.md) | Associar opcionalmente um registro de pesca a um estabelecimento | Aceito |
