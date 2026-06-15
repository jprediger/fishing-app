# ADR-0003: Associar opcionalmente um registro de pesca a um estabelecimento

- **Status:** Aceito
- **Data:** 2026-06-15
- **Decisores:** Equipe Fishing App

## Contexto

`CatchRecord` já é modelado como uma pesca ligada a um `WaterBody` e a um ponto
exato no mapa. O módulo de `Establishment` surgiu depois como camada de pontos
de interesse no mapa, mas sem papel no fluxo de criação de registro.

Queremos permitir que certos estabelecimentos participem do fluxo de criação e
tenham uma listagem própria de registros, sem quebrar a semântica atual de que
o contexto geográfico principal da pesca é o `WaterBody`.

## Decisão

Um `CatchRecord` continua pertencendo obrigatoriamente a um `WaterBody`, mas
pode ter associação opcional a um único `Establishment`.

Detalhamento:

- A associação a `Establishment` é sempre explícita do usuário.
- A proximidade geográfica serve apenas para sugestão de associação, nunca para
  criar vínculo implícito.
- Só `Establishments` das categorias `PESQUEIRO` e `CLUBE` podem receber essa
  associação.
- A associação só é válida quando o ponto da pesca está dentro de um raio
  configurado no backend; o valor inicial é `200 m`.
- O app só oferece estabelecimentos elegíveis que já estejam dentro desse raio.
- Ao iniciar a criação a partir de um `Establishment` associável, o app entra em
  modo de marcar ponto centrado nesse estabelecimento e o mantém pré-marcado
  enquanto o ponto ficar dentro do raio.
- `Establishments` de categorias não associáveis continuam visíveis como POIs,
  mas não exibem ações de criar registro nem de ver registros associados.
- O feed de um `Establishment` mostra apenas registros explicitamente
  associados a ele, respeitando as regras gerais de privacidade.

## Alternativas consideradas

- **Fazer `Establishment` substituir `WaterBody` em alguns registros** — rejeitada
  porque quebraria a semântica atual do domínio, a spec de `CatchRecord` e a
  lógica de privacidade baseada em `RIVER_ONLY`.
- **Associar automaticamente o estabelecimento mais próximo** — rejeitada porque
  cria vínculo silencioso e ambíguo demais para um dado que deve ser declarado
  pelo usuário.
- **Permitir associação para qualquer categoria de estabelecimento** — rejeitada
  porque categorias como `LOJA_PESCA` e `ISCARIA` não sustentam a semântica
  atual de “pescou no estabelecimento”.

## Consequências

- **Positivas:** preserva `WaterBody` como referência principal da pesca, abre
  navegação e feed por estabelecimento, e mantém a associação compreensível para
  o usuário.
- **Negativas / custos:** exige migration em `catch_record`, novos filtros e
  respostas na API, lógica de elegibilidade por categoria/raio e ajustes no
  fluxo do mapa e do formulário.
- **Riscos / mitigações:** imprecisão de GPS ou dados OSM pode excluir
  associações desejadas; mitigar com raio configurável no backend, valor inicial
  conservador (`200 m`) e exposição clara da regra no app.
