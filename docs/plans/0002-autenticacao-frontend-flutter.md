# Plano 0002 — Autenticação no frontend (Flutter)

- **Status:** Proposto
- **Data:** 2026-06-14
- **Relacionado:** [Spec 0002 (auth e usuários)](../specs/0002-autenticacao-e-usuarios.md)
- **Pré-requisito:** Etapa 1 (backend) concluída — commit `23dc56e`.

## Objetivo

Implementar as telas e o fluxo de autenticação no app, consumindo o contrato já
pronto no backend, e **proteger as chamadas ao catálogo** (que agora exigem
token). Ao final: o app abre na tela de login/registro, mantém a sessão entre
aberturas e expõe perfil real + logout.

## Contrato do backend (referência)

| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| `POST` | `/auth/register` | `{name, email, password}` (senha ≥ 8) | `201` vazio · `409` e-mail duplicado |
| `POST` | `/auth/login` | `{email, password}` | `{token, tokenType, expiresIn, user{id,name,email,role}}` · `401` |
| `GET` | `/api/users/me` | — (Bearer) | `user{...}` |
| `PUT` | `/api/users/me` | `{name, password?}` (Bearer) | `user{...}` |

- Token **Bearer**, validade longa (~7 dias), **sem refresh**. Em `401`, o app
  desloga e volta ao login.
- `/api/**` (catálogo de peixes etc.) agora exige token; escrita exige `ADMIN`.
- Dev: admin `admin@fishing.local` / `admin12345`; demo `demo@fishing.local` / `demo12345`.

## Decisões de arquitetura (alinhadas ao código atual)

O app hoje é Flutter "puro": `StatefulWidget` + serviços instanciados por tela,
`http.Client` injetável, modo mock via `--dart-define=USE_MOCK`. **Mantemos esse
estilo** — sem adicionar lib de estado pesada.

| Tema | Decisão |
|---|---|
| Estado de sessão | `AuthController extends ChangeNotifier`, criado no `main.dart` e repassado abaixo (mesma injeção do `FishService` atual). Sem provider/riverpod/bloc. |
| Armazenamento do token | `flutter_secure_storage` (nova dep), encapsulado em `TokenStorage`. |
| HTTP autenticado | `AuthHttpClient` (wrapper de `http.Client`) injeta `Authorization: Bearer` e, em `401`, dispara `AuthController.logout()`. Injetado no `FishService` e nos próximos serviços. |
| Roteamento por sessão | `AuthGate` no topo decide: `unknown`→splash, `unauthenticated`→`LoginScreen`, `authenticated`→`HomeShell`. |
| Paridade mock | `AuthService` respeita `USE_MOCK` (estende `mock_data.dart` p/ `/auth` e `/me`), para o app rodar sem backend. |

## Componentes a criar

```
lib/
  models/
    auth_user.dart          # AuthUser {id, name, email, role}
    auth_session.dart       # AuthSession {token, expiresIn, user}
  services/
    token_storage.dart      # save/read/clear token+user (secure storage)
    auth_service.dart       # register / login / me / updateMe (+ ApiException)
    auth_http_client.dart   # http.Client com Bearer + hook de 401
  state/
    auth_controller.dart    # ChangeNotifier: status, user, login/register/logout/bootstrap
  screens/
    auth_gate.dart          # splash / login / app conforme status
    login_screen.dart
    register_screen.dart
    edit_profile_screen.dart
```

Alterações em arquivos existentes:
- `main.dart` — cria `AuthController`, faz `bootstrap()` no início e usa `AuthGate` como `home`.
- `fish_service.dart` — passa a receber o `AuthHttpClient` (token nas chamadas a `/api/fish`).
- `profile_screen.dart` ("Eu") — dados reais do `AuthController`, botão **Sair** funcional e acesso à edição de perfil.
- `pubspec.yaml` — `flutter_secure_storage`.

## Etapas (fatias verticais, na ordem)

1. **Base de sessão.** Deps + `TokenStorage` + modelos `AuthUser`/`AuthSession`. Testes do storage com fake.
2. **AuthService.** `register/login/me/updateMe`, parse do JSON, mapeamento de `401/409/400` para mensagens amigáveis; suporte a `USE_MOCK`. Testes com `MockClient`.
3. **AuthController + AuthGate.** Estados e transições; `bootstrap()` lê token do storage na abertura. App compila e mostra o login. Testes de transição de estado.
4. **Telas de login e registro.** Formulários com validação espelhando o backend (e-mail válido, senha ≥ 8), estados de loading/erro, tema `AppColors`/`waterGradient`. Registro faz auto-login. Widget tests de validação e navegação.
5. **HTTP autenticado.** `AuthHttpClient` + injeção no `FishService`; `401` → logout → volta ao login. Verifica catálogo carregando com `USE_MOCK=false` autenticado.
6. **Perfil real.** "Eu" mostra `name/email/role` do controller; **Sair** limpa a sessão; `EditProfileScreen` (PUT `/me`, troca de nome/senha).
7. **Testes e fechamento.** Ajustar `widget_test`/`app_e2e_test` (hoje assumem `HomeShell` como home — passarão pelo `AuthGate`, então injetar estado autenticado). `flutter analyze` + `flutter test` limpos.

## Critérios de aceite

- App abre no login quando não há token; vai direto ao `HomeShell` quando há token válido salvo.
- Registro com senha < 8 ou e-mail inválido mostra erro **antes** de chamar a API; e-mail duplicado mostra mensagem de `409`.
- Login bem-sucedido guarda token em secure storage e navega ao app; credenciais inválidas mostram erro de `401`.
- Reabrir o app mantém a sessão (sem novo login) até expirar/deslogar.
- Chamada ao catálogo (`/api/fish`) leva o `Bearer`; um `401` desloga e retorna ao login.
- "Eu" mostra o usuário real e o **Sair** funciona; editar perfil persiste via `PUT /me`.
- `flutter analyze` sem warnings; testes novos e existentes verdes.

## Decisões de escopo (fechadas)

1. **Tela inicial pós-login:** manter o `HomeShell` (Mapa/Buscar/Eu). O `AuthGate` apenas alterna login ↔ `HomeShell`, sem onboarding intermediário.
2. **UI por role:** nesta etapa o USER vê o catálogo **só-leitura**; o app não expõe ações de criação/edição (escrita já é protegida por `ADMIN` no backend). Telas de admin ficam para um passo futuro.
3. **Sessão/expiração:** token de 7 dias **sem refresh**; a sessão salva persiste até expirar e o app **desloga em qualquer `401`** (volta ao login). Sem checagem proativa de `expiresIn` nem opção de "lembrar-me".
4. **Recuperação de senha:** **fora do escopo** — depende de endpoint de reset/e-mail inexistente no backend. Entra quando o backend ganhar o fluxo.
```
