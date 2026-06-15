# Claude Guide

Siga `AGENTS.md`. A regra principal é: validar após qualquer implementação com `bash scripts/validate.sh`.

## Agent skills

### Issue tracker

Issues locais vivem em `.scratch/`, com uma pasta por feature. Veja `docs/agents/issue-tracker.md`.

### Triage labels

Usa a vocabulario padrão do tracker local (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). Veja `docs/agents/triage-labels.md`.

### Domain docs

Contexto único centralizado em `docs/CONTEXT.md` e `docs/adr/`. Veja `docs/agents/domain.md`.
