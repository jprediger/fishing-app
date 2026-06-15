# Agent Guide

Este repositório é um monorepo com dois aplicativos:

- `app/`: Flutter mobile
- `backend/`: Spring Boot API

## Regras de trabalho

- Antes de editar, leia a documentação local da área afetada: `app/README.md` ou `backend/README.md`.
- Prefira `rg` para busca e `apply_patch` para alterações manuais.
- Preserve mudanças existentes do usuário; não reverta arquivos que você não alterou.
- Se a mudança for localizada em `app/` ou `backend/`, rode primeiro a validação do escopo e depois a validação completa.

## Validação

O comando padrão de validação é:

```bash
bash scripts/validate.sh
```

Use estes prefixos quando precisar restringir o escopo ou ajustar o custo da validação:

```bash
bash scripts/validate.sh --frontend
bash scripts/validate.sh --backend
bash scripts/validate.sh --fix
bash scripts/validate.sh --fast
```

## Regra prática

Rode `bash scripts/validate.sh` após qualquer implementação relevante e antes de entregar a mudança.

## Observação

`app/` e `backend/` não são repositórios Git separados neste workspace, então um arquivo na raiz cobre o fluxo padrão.

## Ambiente

- O backend usa Gradle e pode exigir Docker para os testes completos.
- O frontend usa Flutter; algumas validações podem tocar no SDK local fora do workspace.
