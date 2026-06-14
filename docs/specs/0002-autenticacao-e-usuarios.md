# Spec 0002 — Autenticação e modelo único de usuário

- **Status:** Aprovado (decisões fechadas em grill)
- **Data:** 2026-06-14
- **Relacionado:** [Spec 0001 (registro de pesca)](0001-registro-de-pesca.md)
- **Escopo desta spec:** Etapa 1 (backend). A Etapa 2 (telas Flutter) é descrita só em "Próximos passos".

## Problema

O backend tinha **duas modelagens de usuário paralelas e desconexas**:

1. **`User` / `users`** (inglês) — CRUD `/api/users` com senha em **texto puro**, sem
   role. Commitado, com testes.
2. **`Usuario` / `usuarios`** (português) — stack de auth (BCrypt + role + JWT),
   adicionada depois, **não commitada**.

Consequências: **duas migrations `V2`** (Flyway falha no boot — a app nem sobe);
o `SecurityConfig` tranca `/api/**`, mas quem loga é `Usuario` enquanto o CRUD
`/api/users` opera em `User` (tabelas diferentes); naming misto.

O objetivo é **unificar em um único modelo** e deixar a base de auth "concisa e
bem redonda", pronta para as telas de login/registro/perfil da Etapa 2.

## Decisões de produto (fechadas)

| Tema | Decisão |
|---|---|
| Modelo único | **Fundir auth no `User` (inglês).** `Usuario`, `UsuarioRepository` e a migration duplicada são removidos. |
| Esquema | **Reescrever a `V2__create_users.sql` limpa** (dev recria o banco; nada em prod). `password` passa a guardar **hash BCrypt**; adiciona `role`. Sem V4. |
| Senha | **BCrypt.** Mínimo **8** caracteres em todo o contrato (registro e troca via `/me`). |
| Roles | `USER` (padrão) e `ADMIN`. Leitura de `/api/**` exige autenticação; escrita exige `ADMIN`. |
| Acesso a usuário | **Self-service**, não CRUD genérico: `GET /api/users/me` e `PUT /api/users/me` (edita o próprio `name`/`password`; **não** muda `role`). O CRUD `/api/users` antigo é removido. |
| Bootstrap admin + seed | **Estrutura robusta de seed** via registry Java (ver abaixo). |
| Token | **JWT único de validade longa (~7 dias)**, sem refresh. Frontend guarda em secure storage e re-loga no `401`. |
| Resposta de login | `{ token, tokenType, expiresIn, user: { id, name, email, role } }` — evita uma segunda chamada a `/me`. |
| Idioma do contrato | **Inglês** nas chaves JSON e rotas (`name`, `password`, `/auth/register`, `/auth/login`). Mensagens de erro podem permanecer em PT. |
| Testes | **Integração focada** (ver "Critérios de aceite"). |

## Estrutura de seed (registry Java)

Flyway cuida **apenas de schema**. Dados que precisam de hash/ambiente ficam em
Java, num pacote `bootstrap/`:

- `DataSeeder { int order(); void run(); }` — contrato de cada seed.
- `SeedRunner` (`ApplicationRunner`) — descobre todos os beans `DataSeeder`,
  ordena por `order()` e executa cada um **idempotente** (checa existência antes
  de inserir) e **transacional**.
- `AdminUserSeeder` (`order = 0`, **todos os perfis**) — cria o ADMIN a partir de
  `app.admin.email` / `app.admin.password` (env `APP_ADMIN_EMAIL` /
  `APP_ADMIN_PASSWORD`). Default em dev; **fail-fast em prod** se ausente. Só
  insere se o e-mail ainda não existir.
- Seeds de **demo** (**só dev**, `app.seed.demo.enabled=true`) — um `USER` de
  demonstração e um catálogo de exemplo (peixes/produtos), para a app subir
  demonstrável sem poluir produção.

## Requisitos funcionais

- **RF1** `POST /auth/register` cria um `USER` (e-mail único, normalizado em
  minúsculas, senha ≥ 8). `409` se e-mail já existe.
- **RF2** `POST /auth/login` valida credenciais e retorna token + objeto `user`.
  `401` em credenciais inválidas.
- **RF3** `GET /api/users/me` retorna o usuário do token (subject = e-mail).
- **RF4** `PUT /api/users/me` edita `name`/`password` do próprio usuário.
- **RF5** Escrita em `/api/**` (Fish/Produto) exige `ADMIN`; leitura exige
  autenticação; `/auth/**`, health e docs são públicos.
- **RF6** Existe ao menos um `ADMIN` após o boot (seed).

## Critérios de aceite (testes — integração focada)

- `register`: sucesso (`201`) e e-mail duplicado (`409`).
- `login`: sucesso (token + user) e credenciais inválidas (`401`).
- `SecurityConfig`: `GET /api/**` autenticado; escrita só `ADMIN`; `/auth/**`
  público; `PUT /api/users/me` liberado para o próprio usuário autenticado
  **antes** da regra `PUT /api/** → ADMIN`.
- `AdminUserSeeder` idempotente (rodar 2× não duplica).

## Próximos passos — Etapa 2 (frontend Flutter)

Telas de login/registro consumindo `/auth/*`; token em secure storage;
interceptor anexando `Bearer` e tratando `401` (re-login); tela de perfil sobre
`/api/users/me`. Detalhada em spec/plano próprio quando iniciada.
