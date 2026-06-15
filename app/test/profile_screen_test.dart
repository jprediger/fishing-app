import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/screens/profile_screen.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/catch_service.dart';
import 'package:mobile_app/services/profile_service.dart';
import 'package:mobile_app/services/token_storage.dart';
import 'package:mobile_app/state/auth_controller.dart';

import 'support/fake_store.dart';

Map<String, dynamic> _speciesJson(String name) => {
  'id': 7,
  'name': name,
  'description': null,
  'region': 'RS',
  'type': 'FRESHWATER',
  'icon': null,
};

Map<String, dynamic> _waterBodyJson() => {
  'id': 1,
  'name': 'Lago Guaíba',
  'waterType': 'LAKE',
  'geometry': {'type': 'Polygon', 'coordinates': []},
  'osmId': 1001,
  'source': 'OSM',
  'centerLon': -51.2,
  'centerLat': -30.08,
  'catchCount': 21,
};

Map<String, dynamic> _catchJson({
  required int id,
  required int userId,
  required String authorName,
  required String species,
}) => {
  'id': id,
  'author': {'id': userId, 'name': authorName},
  'species': _speciesJson(species),
  'waterBody': _waterBodyJson(),
  'location': {'lat': -30.08, 'lon': -51.2},
  'locationVisibility': 'EXACT',
  'weightGrams': 1200,
  'lengthMm': 450,
  'description': 'Boa captura',
  'fishingMethod': 'ARREMESSO',
  'purpose': 'SPORT',
  'caughtAt': '2026-06-14T12:00:00Z',
  'mine': userId == 1,
  'photos': const [],
};

AuthController _authController() {
  return AuthController(
    authService: AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'token': 'jwt-123',
            'tokenType': 'Bearer',
            'expiresIn': 604800,
            'user': {
              'id': 1,
              'name': 'Ana',
              'email': 'ana@fishing.local',
              'role': 'USER',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      baseUrl: 'http://test.local',
    ),
    storage: TokenStorage(store: FakeStore()),
  );
}

Widget _wrap(ProfileScreen screen) => MaterialApp(home: screen);

void main() {
  testWidgets('perfil próprio mostra stats e ações', (tester) async {
    final auth = _authController();
    await auth.login('ana@fishing.local', 'x');

    final client = MockClient((request) async {
      if (request.url.path == '/api/users/1') {
        return http.Response(
          jsonEncode({
            'id': 1,
            'name': 'Ana',
            'avatarPath': 'avatars/ana.webp',
            'role': 'USER',
            'memberSince': '2024-01-10T12:00:00Z',
            'catchCount': 12,
            'speciesCount': 5,
            'waterBodyCount': 3,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      expect(request.url.path, '/api/catches');
      expect(request.url.queryParameters['userId'], '1');
      return http.Response(
        jsonEncode({
          'content': [
            _catchJson(
              id: 1,
              userId: 1,
              authorName: 'Ana',
              species: 'Tucunaré',
            ),
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        ProfileScreen(
          auth: auth,
          catchService: CatchService(
            client: client,
            baseUrl: 'http://test.local',
          ),
          profileService: ProfileService(
            client: client,
            baseUrl: 'http://test.local',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsWidgets);
    expect(find.text('12'), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.text('Tucunaré'), findsOneWidget);
  });

  testWidgets('excluir registro volta ao perfil com a lista atualizada', (
    tester,
  ) async {
    final auth = _authController();
    await auth.login('ana@fishing.local', 'x');

    var listCalls = 0;
    var deleted = false;

    final client = MockClient((request) async {
      if (request.url.path == '/api/users/1') {
        return http.Response(
          jsonEncode({
            'id': 1,
            'name': 'Ana',
            'avatarPath': null,
            'role': 'USER',
            'memberSince': '2024-01-10T12:00:00Z',
            'catchCount': deleted ? 0 : 1,
            'speciesCount': deleted ? 0 : 1,
            'waterBodyCount': deleted ? 0 : 1,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.method == 'DELETE' && request.url.path == '/api/catches/1') {
        deleted = true;
        return http.Response('', 204);
      }

      expect(request.url.path, '/api/catches');
      listCalls += 1;
      return http.Response(
        jsonEncode({
          'content': deleted
              ? []
              : [
                  _catchJson(
                    id: 1,
                    userId: 1,
                    authorName: 'Ana',
                    species: 'Tucunaré',
                  ),
                ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        ProfileScreen(
          auth: auth,
          catchService: CatchService(
            client: client,
            baseUrl: 'http://test.local',
          ),
          profileService: ProfileService(
            client: client,
            baseUrl: 'http://test.local',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Tucunaré'), findsOneWidget);

    // Abre o detalhe do registro.
    await tester.tap(find.text('Tucunaré'));
    await tester.pumpAndSettle();

    // Exclui e confirma no diálogo.
    await tester.ensureVisible(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();

    // Voltou ao perfil e a lista foi recarregada sem o registro.
    expect(find.text('Tucunaré'), findsNothing);
    expect(find.text('Nenhum registro ainda.'), findsOneWidget);
    expect(listCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('perfil de outro oculta ações próprias', (tester) async {
    final auth = _authController();
    await auth.login('ana@fishing.local', 'x');

    final client = MockClient((request) async {
      if (request.url.path == '/api/users/7') {
        return http.Response(
          jsonEncode({
            'id': 7,
            'name': 'Bruno',
            'avatarPath': null,
            'role': 'ADMIN',
            'memberSince': '2023-05-01T12:00:00Z',
            'catchCount': 4,
            'speciesCount': 2,
            'waterBodyCount': 2,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      expect(request.url.path, '/api/catches');
      expect(request.url.queryParameters['userId'], '7');
      return http.Response(
        jsonEncode({'content': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        ProfileScreen(
          userId: 7,
          auth: auth,
          catchService: CatchService(
            client: client,
            baseUrl: 'http://test.local',
          ),
          profileService: ProfileService(
            client: client,
            baseUrl: 'http://test.local',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bruno'), findsWidgets);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.text('Nenhum registro ainda.'), findsOneWidget);
  });
}
