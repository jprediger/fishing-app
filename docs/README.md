# Documentação — Fishing App

Esta pasta é a **fonte única de verdade** para tudo em `.md` do projeto:
planejamentos, decisões de arquitetura, specs, guias e referência técnica.

Foi estruturada para **desenvolvimento assistido por IA**: documentos curtos,
versionados, numerados e com um único assunto cada — fáceis de um agente (ou
pessoa) localizar, citar (`docs/plans/0001-...md:42`) e manter atualizados.

## Estrutura

| Pasta | O que vive aqui | Quando criar |
|---|---|---|
| [`CONTEXT.md`](./CONTEXT.md) | Visão geral do sistema + glossário de domínio. **É o primeiro arquivo que uma IA deve ler.** | Manter sempre atualizado |
| [`adr/`](./adr/) | Architecture Decision Records — decisões técnicas com contexto e consequências. | A cada decisão arquitetural relevante |
| [`plans/`](./plans/) | Planos de implementação (passo a passo de uma feature/refactor). | Antes de implementar algo não-trivial |
| [`specs/`](./specs/) | Especificações de feature / PRDs — o "o quê" e "porquê" antes do "como". | Ao definir uma feature nova |
| [`guides/`](./guides/) | How-tos operacionais (setup, rodar, deploy, contribuir). | Conhecimento que se repete |
| [`reference/`](./reference/) | Referência estável: modelo de dados, endpoints, contratos. | Descrever o que existe hoje |

## Convenções

- **Idioma:** português (alinhado ao código e comentários existentes).
- **Nomes:** `kebab-case`. Documentos sequenciais usam prefixo numérico de 4
  dígitos: `0001-titulo-curto.md`.
- **Um assunto por arquivo.** Se um doc cresce demais, quebre.
- **Estado no topo.** Planos e ADRs declaram seu status (Proposto / Aceito /
  Implementado / Substituído).
- **Linkar, não duplicar.** Referencie outros docs em vez de repetir conteúdo.
- **ADR é imutável após "Aceito".** Mudou de ideia? Crie um novo ADR que
  substitui o anterior (`Substitui: ADR-000X`).

## Relação com arquivos de IA na raiz

- `CLAUDE.md` / `AGENTS.md` (raiz, se existirem) = instruções **curtas e
  estáveis** para o agente. Devem **apontar para esta pasta**, não duplicá-la.
- Esta pasta = o conhecimento detalhado e versionado.
