# Fishing App

Aplicativo de pesca desenvolvido na Univates. O projeto é um monorepo com duas partes:

| Pasta       | O que é                          | Stack                                  |
|-------------|----------------------------------|----------------------------------------|
| [`backend/`](backend/README.md) | API REST (peixes, usuários, produtos) | Java 21 · Spring Boot 4 · PostgreSQL 16 |
| [`app/`](app/README.md)         | Aplicativo mobile (mapa, busca, perfil) | Flutter 3 · Dart                       |

```
fishing-app/
├── backend/   # API Spring Boot — ver backend/README.md
├── app/       # App Flutter      — ver app/README.md
└── README.md  # este arquivo
```

## Como rodar (visão geral)

O app e o backend rodam de forma independente. Para o fluxo completo, suba o backend primeiro e depois o app apontando para ele.

### 1. Backend

```bash
cd backend
docker compose up -d     # sobe o PostgreSQL
./gradlew bootRun        # sobe a API em http://localhost:8080
```

Documentação da API (com a aplicação no ar): http://localhost:8080/docs

Detalhes completos em **[backend/README.md](backend/README.md)**.

### 2. App (Flutter)

```bash
cd app
flutter pub get
flutter run              # roda em modo mock (não precisa do backend no ar)
```

Para conectar no backend real em vez dos dados mockados:

```bash
flutter run --dart-define=USE_MOCK=false
```

Detalhes completos em **[app/README.md](app/README.md)**.

## Pré-requisitos

- **Backend:** JDK 21, Docker + Docker Compose
- **App:** Flutter SDK 3.11+ (Dart 3.11+)
