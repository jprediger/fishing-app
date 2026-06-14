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
import 'package:mobile_app/services/fish_service.dart';
import 'package:mobile_app/services/water_body_service.dart';
import 'package:mobile_app/services/token_storage.dart';
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
    final fishClient = MockClient(
      (_) async => http.Response(
        _pageJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final waterClient = MockClient((request) async {
      expect(request.url.path, '/api/water-bodies');
      return http.Response(
        _waterBodiesJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      FishingApp(
        auth: auth,
        fishService: FishService(client: fishClient),
        waterBodyService: WaterBodyService(client: waterClient),
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

    // Aba Eu mostra o usuário real da sessão.
    await tester.tap(find.text('Eu'));
    await tester.pumpAndSettle();
    expect(find.text('Pescador Demo'), findsOneWidget);
    expect(find.text('demo@fishing.local'), findsOneWidget);
  });

  testWidgets('logout volta ao login', (tester) async {
    final auth = await _authenticated();
    final fishClient = MockClient(
      (_) async => http.Response(
        _pageJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final waterClient = MockClient((request) async {
      expect(request.url.path, '/api/water-bodies');
      return http.Response(
        _waterBodiesJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      FishingApp(
        auth: auth,
        fishService: FishService(client: fishClient),
        waterBodyService: WaterBodyService(client: waterClient),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eu'));
    await tester.pumpAndSettle();

    // "Sair" fica no fim da lista; rola até ele antes de tocar.
    await tester.scrollUntilVisible(find.text('Sair'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    // AuthGate troca para a tela de login.
    expect(auth.status, AuthStatus.unauthenticated);
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
  });
}
