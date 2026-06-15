import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/models/water_body.dart';
import 'package:mobile_app/screens/catch_feed_screen.dart';
import 'package:mobile_app/services/catch_service.dart';

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
  required String species,
  required bool mine,
  required String authorName,
  required String? authorAvatarPath,
}) => {
  'id': id,
  'author': {
    'id': mine ? 10 : 11,
    'name': authorName,
    'avatarPath': authorAvatarPath,
  },
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
  'mine': mine,
  'photos': const [],
};

Widget _wrap({required CatchService catchService}) => MaterialApp(
  home: CatchFeedScreen(
    body: WaterBody.fromJson(_waterBodyJson()),
    catchService: catchService,
  ),
);

void main() {
  testWidgets('renderiza posts e abre detalhe ao tocar', (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/catches');
      expect(request.url.queryParameters['waterBodyId'], '1');
      expect(request.url.queryParameters['sort'], 'createdAt,desc');
      return http.Response(
        jsonEncode({
          'content': [
            _catchJson(
              id: 1,
              species: 'Tucunaré',
              mine: true,
              authorName: 'Eu',
              authorAvatarPath: 'avatars/eu.webp',
            ),
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tucunaré'), findsOneWidget);
    expect(find.text('Você'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      'http://test.local/uploads/avatars/eu.webp',
    );

    await tester.tap(find.text('Tucunaré'));
    await tester.pumpAndSettle();

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
  });

  testWidgets('carrega próxima página ao rolar', (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/catches');
      expect(request.url.queryParameters['waterBodyId'], '1');
      final page = request.url.queryParameters['page'];
      if (page == '0') {
        return http.Response(
          jsonEncode({
            'content': List.generate(
              20,
              (index) => _catchJson(
                id: index + 1,
                species: index == 0 ? 'Tucunaré' : 'Bagre',
                mine: index == 0,
                authorName: index == 0 ? 'Eu' : 'Outro',
                authorAvatarPath: index == 0
                    ? 'avatars/eu.webp'
                    : 'avatars/outro.webp',
              ),
            ),
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      expect(page, '1');
      return http.Response(
        jsonEncode({
          'content': [
            _catchJson(
              id: 21,
              species: 'Dourado',
              mine: false,
              authorName: 'Outro',
              authorAvatarPath: 'avatars/outro.webp',
            ),
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Tucunaré'), findsOneWidget);
    expect(find.text('Dourado'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Dourado'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Dourado'), findsOneWidget);
  });

  testWidgets('mostra vazio quando nao ha registros', (tester) async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'content': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum registro neste corpo d\'água ainda.'),
      findsOneWidget,
    );
  });
}
