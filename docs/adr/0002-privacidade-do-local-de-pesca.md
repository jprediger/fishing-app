# ADR-0002: Privacidade do local de pesca

- **Status:** Aceito
- **Data:** 2026-06-14
- **Decisores:** equipe Fishing App
- **Relacionado:** [Spec 0001](../specs/0001-registro-de-pesca.md)

## Contexto

Pescadores costumam proteger seus "pontos quentes". Ao registrar uma pesca, o
usuário precisa **sempre** marcar a localização no mapa, mas deve poder decidir
se torna público o **ponto exato** ou apenas o **corpo d'água** (rio/lago).
Vazar o ponto exato de quem pediu sigilo é uma falha de privacidade, não só de UX.

## Decisão

Cada `catch_record` tem `location` (ponto exato, sempre obrigatório) e um campo
`location_visibility` com dois valores:

- **`EXACT`** — ponto exato é público.
- **`RIVER_ONLY`** — ponto exato é **privado**; publicamente expõe-se apenas o
  `water_body` (nome + centroide/geometria).

A regra é aplicada na **camada de DTO/serialização do backend**: para um
requisitante que **não é o dono**, quando `RIVER_ONLY`, o campo `location`
**não é incluído no JSON** — em vez disso retorna-se o corpo d'água. O **dono
sempre** vê o próprio ponto exato.

## Alternativas consideradas

- **Filtrar só na UI do app** — o ponto ainda viajaria no JSON e poderia ser lido
  via API/inspeção. Rejeitado: não é privacidade real.
- **Ofuscar o ponto (jitter aleatório)** — manter `location` mas embaralhar
  alguns metros. Rejeitado: dá falsa precisão e ainda revela região exata; o
  centroide do corpo d'água comunica melhor "aproximado".
- **Dois campos (exato privado + aproximado público)** — redundante; o
  `water_body` já fornece o público.

## Consequências

- **Positivas:** privacidade garantida no servidor; modelo simples (1 enum +
  reuso do `water_body`).
- **Negativas / custos:** todo endpoint que retorna pescas precisa conhecer o
  requisitante (dono vs. não-dono) e aplicar a regra — exige teste de
  autorização dedicado para evitar regressão de vazamento.
- **Riscos / mitigações:** esquecer a regra em um novo endpoint vaza o ponto →
  centralizar o mapeamento em um único `toDto(catch, requester)` e cobrir com
  teste.
