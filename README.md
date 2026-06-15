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
./gradlew bootRun        # sobe a API em http://localhost:8081
```

Documentação da API (com a aplicação no ar): http://localhost:8081/docs

Detalhes completos em **[backend/README.md](backend/README.md)**.

### 2. App (Flutter)

```bash
cd app
flutter pub get
flutter run              # roda o app; para dados reais, deixe o backend no ar
```

Para apontar explicitamente para outro backend:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8081
```

Detalhes completos em **[app/README.md](app/README.md)**.

## Validação

Antes de considerar uma implementação pronta, rode a validação completa do repositório:

```bash
bash scripts/validate.sh
```

Esse comando executa as checagens do frontend e do backend em sequência. Os prefixos mais usados são:

```bash
bash scripts/validate.sh --frontend
bash scripts/validate.sh --backend
bash scripts/validate.sh --fix
bash scripts/validate.sh --fast
```

Recomendação prática: rode `bash scripts/validate.sh` após qualquer implementação e antes de commitar ou abrir PR.

## Pré-requisitos

- **Backend:** JDK 21, Docker + Docker Compose
- **App:** Flutter SDK 3.11+ (Dart 3.11+)
