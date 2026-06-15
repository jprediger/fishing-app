// Teste end-to-end (headless) do app de pesca.
//
// Roda a árvore completa (FishingApp) através do AuthGate, com um
// AuthController autenticado e um cliente HTTP simulado injetado na camada de
// serviço. Verifica a navegação entre as abas, o consumo do catálogo e o
// logout voltando ao login.
//
// Roda via: flutter test test/app_e2e_test.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/catch_service.dart';
import 'package:mobile_app/services/establishment_service.dart';
import 'package:mobile_app/services/fish_service.dart';
import 'package:mobile_app/services/profile_service.dart';
import 'package:mobile_app/services/token_storage.dart';
import 'package:mobile_app/services/water_body_service.dart';
import 'package:mobile_app/state/auth_controller.dart';

import 'support/fake_store.dart';

const _pageJson = '''
{
  "content": [
    { "id": 1, "name": "Tucunaré", "region": "Amazônia",
      "type": "FRESHWATER", "icon": { "path": "/i.png" } },
    { "id": 2, "name": "Dourado", "region": "Pantanal",
      "type": "FRESHWATER", "icon": null }
  ],
  "totalElements": 2, "totalPages": 1
}
''';

const _waterBodiesJson = '''
[
  {
    "id": 1,
    "name": "Lago Guaíba",
    "waterType": "LAKE",
    "geometry": {
      "type": "Polygon",
      "coordinates": [[[ -51.40, -30.14 ], [ -51.24, -30.22 ], [ -51.04, -30.16 ], [ -51.07, -29.98 ], [ -51.25, -29.93 ], [ -51.40, -30.14 ]]]
    },
    "osmId": 1001,
    "source": "OSM",
    "centerLon": -51.20,
    "centerLat": -30.08
  }
]
''';

const _profileJson = '''
{
  "id": 2,
  "name": "Pescador Demo",
  "role": "USER",
  "memberSince": "2026-06-01T00:00:00Z",
  "catchCount": 3,
  "speciesCount": 2,
  "waterBodyCount": 1
}
''';

const _catchPageJson = '''
{
  "content": [],
  "totalElements": 0,
  "totalPages": 0
}
''';

const _establishmentsJson = '''
[
  {
    "id": 1,
    "name": "Loja do Pescador",
    "category": "LOJA_PESCA",
    "address": "Centro",
    "lon": -51.20,
    "lat": -30.05
  }
]
''';

const _loginBody = {
  'token': 'jwt-123',
  'tokenType': 'Bearer',
  'expiresIn': 604800,
  'user': {
    'id': 2,
    'name': 'Pescador Demo',
    'email': 'demo@fishing.local',
    'role': 'USER',
  },
};

Future<AuthController> _authenticated() async {
  final auth = AuthController(
    authService: AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(_loginBody),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      baseUrl: 'http://test.local',
    ),
    storage: TokenStorage(store: FakeStore()),
  );
  await auth.login('demo@fishing.local', 'demo12345');
  return auth;
}

void main() {
  testWidgets('autenticado: navega entre as abas e carrega peixes', (
    tester,
  ) async {
    final auth = await _authenticated();
    final appClient = MockClient((request) async {
      if (request.url.path == '/api/fish') {
        return http.Response(
          _pageJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/water-bodies') {
        return http.Response(
          _waterBodiesJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/users/2') {
        return http.Response(
          _profileJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches' &&
          request.url.queryParameters['userId'] == '2') {
        return http.Response(
          _catchPageJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches') {
        return http.Response(
          _catchPageJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response('', 404);
    });
    final establishmentClient = MockClient((request) async {
      expect(request.url.path, '/api/establishments');
      return http.Response(
        _establishmentsJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      FishingApp(
        auth: auth,
        fishService: FishService(client: appClient),
        catchService: CatchService(client: appClient),
        profileService: ProfileService(client: appClient),
        waterBodyService: WaterBodyService(client: appClient),
        establishmentService: EstablishmentService(client: establishmentClient),
      ),
    );
    await tester.pumpAndSettle();

    // Gate decide pelo HomeShell -> inicia no Mapa.
    expect(find.text('Mapa'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Aba Buscar carrega os peixes do backend simulado.
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Tucunaré'), findsOneWidget);
    expect(find.text('Dourado'), findsOneWidget);

    // Aba Locais carrega os estabelecimentos do backend simulado.
    await tester.tap(find.text('Locais'));
    await tester.pumpAndSettle();
    expect(find.text('Loja do Pescador'), findsOneWidget);

    // Aba Eu mostra o usuário real da sessão.
    await tester.tap(find.text('Eu'));
    await tester.pumpAndSettle();
    expect(find.text('Pescador Demo'), findsWidgets);
    expect(find.textContaining('Pescando desde'), findsWidgets);
  });

  testWidgets('logout volta ao login', (tester) async {
    final auth = await _authenticated();
    final appClient = MockClient((request) async {
      if (request.url.path == '/api/fish') {
        return http.Response(
          _pageJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/water-bodies') {
        return http.Response(
          _waterBodiesJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/users/2') {
        return http.Response(
          _profileJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches' &&
          request.url.queryParameters['userId'] == '2') {
        return http.Response(
          _catchPageJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches') {
        return http.Response(
          _catchPageJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response('', 404);
    });
    final establishmentClient = MockClient(
      (_) async => http.Response(
        _establishmentsJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    await tester.pumpWidget(
      FishingApp(
        auth: auth,
        fishService: FishService(client: appClient),
        catchService: CatchService(client: appClient),
        profileService: ProfileService(client: appClient),
        waterBodyService: WaterBodyService(client: appClient),
        establishmentService: EstablishmentService(client: establishmentClient),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    // AuthGate troca para a tela de login.
    expect(auth.status, AuthStatus.unauthenticated);
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
  });
}
