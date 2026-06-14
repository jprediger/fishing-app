# Fishing App — Mobile (Flutter)

Aplicativo mobile do projeto de pesca (Univates). Consome a API REST do [backend](../backend/README.md) e funciona em modo mock por padrão, sem precisar do backend no ar.

## Stack

| Camada       | Tecnologia                                  |
|--------------|---------------------------------------------|
| Framework    | Flutter 3.11+ (Material 3)                  |
| Linguagem    | Dart 3.11+                                   |
| Mapa         | `flutter_map` + `latlong2` (tiles OpenStreetMap, sem API key) |
| HTTP         | `http`                                      |
| Testes       | `flutter_test` + `http/testing` (MockClient) |

## Funcionalidades

O app é organizado em três abas (`NavigationBar`):

- **Mapa** — pontos de pesca em um mapa OpenStreetMap (`flutter_map`).
- **Buscar** — catálogo de espécies de peixe consumido de `GET /api/fish`, com busca por nome e filtro por habitat (água doce / salgada / salobra).
- **Eu** — perfil do pescador e estatísticas.

## Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.11 ou superior (inclui o Dart SDK).
- Um destino para rodar: emulador Android, simulador iOS, Chrome (web) ou desktop.

Verifique seu ambiente com:

```bash
flutter doctor
```

## Como rodar

```bash
# 1. Instala as dependências
flutter pub get

# 2. Roda o app (modo mock por padrão — não precisa do backend)
flutter run
```

Para escolher o dispositivo, liste os disponíveis e passe o id:

```bash
flutter devices
flutter run -d chrome      # exemplo: rodar no navegador
```

## Modo mock vs. backend real

Por padrão o app usa um catálogo de peixes mockado (`lib/services/mock_data.dart`), no mesmo formato paginado que o backend retorna. Assim dá para desenvolver a UI sem subir a API.

Para apontar para o backend real:

```bash
flutter run --dart-define=USE_MOCK=false
```

### Endereço do backend

O `ApiConfig` (`lib/config/api_config.dart`) escolhe a URL base conforme a plataforma:

| Plataforma                  | URL base usada            |
|-----------------------------|---------------------------|
| Emulador Android            | `http://10.0.2.2:8080`    |
| Web / desktop / iOS sim.    | `http://localhost:8080`   |

Para sobrescrever (ex.: backend em outra máquina da rede):

```bash
flutter run --dart-define=USE_MOCK=false \
            --dart-define=API_BASE_URL=http://192.168.0.10:8080
```

## Testes

```bash
flutter test
```

| Arquivo                      | O que cobre                                            |
|------------------------------|--------------------------------------------------------|
| `test/fish_service_test.dart`| `FishService` com um `MockClient` (parsing do `Page`)  |
| `test/widget_test.dart`      | Renderização de widgets                                |
| `test/app_e2e_test.dart`     | Fluxo de ponta a ponta entre as abas                   |

## Build de produção

```bash
flutter build apk        # Android (APK)
flutter build appbundle  # Android (Play Store)
flutter build ios        # iOS (requer macOS + Xcode)
flutter build web        # Web
```

Lembre de incluir o `--dart-define=USE_MOCK=false` (e, se necessário, `API_BASE_URL`) no build que aponta para o backend real.

## Estrutura de pastas

```
app/lib/
├── main.dart              # entrypoint, tema (AppColors) e MaterialApp
├── config/
│   └── api_config.dart    # URL base do backend por plataforma / --dart-define
├── models/
│   └── fish.dart          # modelo Fish + enum FishType (espelha o backend)
├── screens/
│   ├── home_shell.dart    # navegação entre as abas (Mapa, Buscar, Eu)
│   ├── map_screen.dart    # mapa com pontos de pesca
│   ├── search_screen.dart # busca de espécies (consome /api/fish)
│   └── profile_screen.dart# perfil do pescador
└── services/
    ├── fish_service.dart  # acesso ao endpoint /api/fish
    └── mock_data.dart     # catálogo mockado (MockClient)
```
