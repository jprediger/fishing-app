import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/models/fish.dart';
import 'package:mobile_app/screens/catch_form_screen.dart';
import 'package:mobile_app/screens/map_screen.dart';
import 'package:mobile_app/services/catch_service.dart';
import 'package:mobile_app/services/water_body_service.dart';
import 'package:mobile_app/theme/app_colors.dart';
import 'package:mobile_app/widgets/map_marker.dart';

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

const _fishPageJson = '''
{
  "content": [
    {
      "id": 7,
      "name": "Tucunaré",
      "description": "desc",
      "region": "Amazônia",
      "type": "FRESHWATER",
      "icon": null
    }
  ],
  "totalElements": 1,
  "totalPages": 1
}
''';

const _createdCatchJson = '''
{
  "id": 77,
  "waterBody": {
    "id": 1,
    "name": "Lago Guaíba",
    "waterType": "LAKE",
    "geometry": {"type":"Polygon","coordinates":[]},
    "osmId": 1001,
    "source": "OSM",
    "centerLon": -51.20,
    "centerLat": -30.08,
    "catchCount": 1
  },
  "location": {"lat": -30.05, "lon": -50.95},
  "locationVisibility": "EXACT",
  "species": {
    "id": 7,
    "name": "Tucunaré",
    "description": "desc",
    "region": "Amazônia",
    "type": "FRESHWATER",
    "icon": null
  },
  "fishingMethod": "ARREMESSO",
  "purpose": "SPORT",
  "caughtAt": "2026-06-14T12:00:00Z",
  "photos": [
    {
      "id": 1,
      "filePath": "photo-1.jpg",
      "position": 0,
      "createdAt": "2026-06-14T12:00:00Z"
    }
  ],
  "mine": true
}
''';

Widget _wrap(
  WaterBodyService waterBodyService, {
  CatchService? catchService,
  double? debugInitialZoom,
  LatLng? draftPoint,
}) => MaterialApp(
  home: MapScreen(
    waterBodyService: waterBodyService,
    catchService: catchService,
    showTiles: false,
    debugInitialZoom: debugInitialZoom,
    debugInitialDraftPoint: draftPoint,
  ),
);

void main() {
  testWidgets('pin solto mostra corpo d\'água mais próximo', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/water-bodies/nearest') {
        return http.Response(
          '''
          {
            "id": 1,
            "name": "Lago Guaíba",
            "waterType": "LAKE",
            "geometry": {"type":"Polygon","coordinates":[]},
            "osmId": 1001,
            "source": "OSM",
            "centerLon": -51.20,
            "centerLat": -30.08,
            "distanceMeters": 432.0
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches') {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response(
        _waterBodiesJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
        draftPoint: const LatLng(-30.05, -50.95),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Corpos d\'água'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Marcar ponto'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Lago Guaíba'), findsOneWidget);
    expect(find.textContaining('Criar registro aqui'), findsOneWidget);
  });

  testWidgets('após salvar registro no popup o mapa volta ao default', (
    tester,
  ) async {
    var created = false;
    final client = MockClient((request) async {
      if (request.url.path == '/api/water-bodies/nearest') {
        return http.Response('', 404);
      }

      if (request.url.path == '/api/water-bodies') {
        return http.Response(
          _waterBodiesJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/fish') {
        return http.Response(
          _fishPageJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches' && request.method == 'GET') {
        return http.Response(
          created ? '[$_createdCatchJson]' : '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches' && request.method == 'POST') {
        created = true;
        return http.Response(
          _createdCatchJson,
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches/77') {
        return http.Response(
          _createdCatchJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches/77/photos') {
        return http.Response(
          '''
            [
              {
                "id": 1,
                "filePath": "photo-1.jpg",
                "position": 0,
                "createdAt": "2026-06-14T12:00:00Z"
              }
            ]
            ''',
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      throw StateError('unhandled ${request.method} ${request.url}');
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
        debugInitialZoom: 12.5,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byType(MapMarker).first);
    await tester.pumpAndSettle();

    expect(find.text('Lago Guaíba'), findsOneWidget);
    expect(find.textContaining('Criar registro aqui'), findsOneWidget);

    await tester.tap(find.textContaining('Criar registro aqui'));
    await tester.pumpAndSettle();

    final form = tester.widget<CatchFormScreen>(find.byType(CatchFormScreen));
    form.draft.setSpecies(
      const Fish(id: 7, name: 'Tucunaré', type: FishType.freshwater),
    );
    form.draft.addPhotos([
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'photo-1.jpg',
        mimeType: 'image/jpeg',
      ),
    ]);
    await tester.pump();
    expect(find.text('Tucunaré'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar registro'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('Lago Guaíba'), findsNothing);
    expect(find.textContaining('Criar registro aqui'), findsNothing);
    expect(find.text('Corpos d\'água'), findsOneWidget);
    expect(find.byIcon(Icons.water_drop), findsWidgets);
  });

  testWidgets('404 desabilita CTA do pin solto', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/water-bodies/nearest') {
        return http.Response('', 404);
      }

      if (request.url.path == '/api/catches') {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response(
        _waterBodiesJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
        draftPoint: const LatLng(-30.05, -50.95),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.text('Nenhuma água num raio de 5 km.'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Criar registro aqui'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('CTA do mapa abre o wizard com ponto e água resolvidos', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/water-bodies/nearest') {
        return http.Response(
          '''
          {
            "id": 1,
            "name": "Lago Guaíba",
            "waterType": "LAKE",
            "geometry": {"type":"Polygon","coordinates":[]},
            "osmId": 1001,
            "source": "OSM",
            "centerLon": -51.20,
            "centerLat": -30.08,
            "distanceMeters": 432.0
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/catches') {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response(
        _waterBodiesJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
        draftPoint: const LatLng(-30.05, -50.95),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar registro aqui'));
    await tester.pumpAndSettle();

    expect(find.text('Registrar pesca'), findsOneWidget);
    expect(find.text('Lago Guaíba'), findsOneWidget);
    expect(find.textContaining('-30.05'), findsOneWidget);
    expect(find.textContaining('-50.95'), findsOneWidget);
  });

  testWidgets('pescas aparecem com cor própria e de outros', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/water-bodies/nearest') {
        return http.Response('', 404);
      }

      if (request.url.path == '/api/catches') {
        return http.Response(
          '''
          [
            {
              "id": 11,
              "species": {
                "id": 1,
                "name": "Tucunaré",
                "description": "desc",
                "region": "RS",
                "type": "FRESHWATER"
              },
              "waterBody": {
                "id": 1,
                "name": "Lago Guaíba",
                "waterType": "LAKE",
                "geometry": {"type":"Polygon","coordinates":[]},
                "osmId": 1001,
                "source": "OSM",
                "centerLon": -51.20,
                "centerLat": -30.08
              },
              "location": {"lat": -30.08, "lon": -51.20},
              "locationVisibility": "EXACT",
              "fishingMethod": "ARREMESSO",
              "purpose": "SPORT",
              "caughtAt": "2026-06-14T12:00:00Z",
              "mine": true,
              "photos": []
            },
            {
              "id": 12,
              "species": {
                "id": 1,
                "name": "Tucunaré",
                "description": "desc",
                "region": "RS",
                "type": "FRESHWATER"
              },
              "waterBody": {
                "id": 1,
                "name": "Lago Guaíba",
                "waterType": "LAKE",
                "geometry": {"type":"Polygon","coordinates":[]},
                "osmId": 1001,
                "source": "OSM",
                "centerLon": -51.20,
                "centerLat": -30.08
              },
              "location": {"lat": -30.08, "lon": -51.20},
              "locationVisibility": "EXACT",
              "fishingMethod": "ARREMESSO",
              "purpose": "SPORT",
              "caughtAt": "2026-06-14T12:00:00Z",
              "mine": false,
              "photos": []
            }
          ]
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response(
        _waterBodiesJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
        debugInitialZoom: 12.5,
      ),
    );

    await tester.pumpAndSettle();

    final markers = tester
        .widgetList<MapMarker>(find.byType(MapMarker))
        .toList();
    expect(
      markers.any((marker) => marker.kind.color == AppColors.markerCatchMine),
      isTrue,
    );
    expect(
      markers.any((marker) => marker.kind.color == AppColors.markerCatchOther),
      isTrue,
    );
  });

  testWidgets('pescas RIVER_ONLY não viram pin individual', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/water-bodies/nearest') {
        return http.Response('', 404);
      }

      if (request.url.path == '/api/catches') {
        return http.Response(
          '''
          [
            {
              "id": 21,
              "species": {
                "id": 1,
                "name": "Tucunaré",
                "description": "desc",
                "region": "RS",
                "type": "FRESHWATER"
              },
              "waterBody": {
                "id": 1,
                "name": "Lago Guaíba",
                "waterType": "LAKE",
                "geometry": {"type":"Polygon","coordinates":[]},
                "osmId": 1001,
                "source": "OSM",
                "centerLon": -51.20,
                "centerLat": -30.08
              },
              "location": {"lat": -30.08, "lon": -51.20},
              "locationVisibility": "RIVER_ONLY",
              "fishingMethod": "ARREMESSO",
              "purpose": "SPORT",
              "caughtAt": "2026-06-14T12:00:00Z",
              "mine": false,
              "photos": []
            }
          ]
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response(
        _waterBodiesJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
        debugInitialZoom: 12.5,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.set_meal), findsNothing);
  });

  testWidgets('pin de corpo d\'água mostra badge de contagem', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/water-bodies/nearest') {
        return http.Response('', 404);
      }

      if (request.url.path == '/api/catches') {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response(
        '''
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
            "centerLat": -30.08,
            "catchCount": 12
          }
        ]
        ''',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
        debugInitialZoom: 12.5,
      ),
    );

    await tester.pumpAndSettle();

    final markers = tester
        .widgetList<MapMarker>(find.byType(MapMarker))
        .toList();
    expect(markers.any((marker) => marker.badgeCount == 12), isTrue);
  });

  testWidgets('botão Ver registros abre feed do corpo d\'água', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/water-bodies/nearest') {
        return http.Response('', 404);
      }

      if (request.url.path == '/api/catches') {
        expect(request.url.queryParameters['page'], '0');
        expect(request.url.queryParameters['size'], '20');

        if (request.url.queryParameters['waterBodyId'] != null) {
          expect(request.url.queryParameters['waterBodyId'], '1');
          expect(request.url.queryParameters['sort'], 'createdAt,desc');
          return http.Response(
            jsonEncode({'content': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response(
        '''
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
            "centerLat": -30.08,
            "catchCount": 12
          }
        ]
        ''',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
        catchService: CatchService(
          client: client,
          baseUrl: 'http://test.local',
        ),
        debugInitialZoom: 12.5,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byType(MapMarker).first);
    await tester.pumpAndSettle();

    expect(find.text('Ver registros (12)'), findsOneWidget);
    await tester.tap(find.text('Ver registros (12)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum registro neste corpo d\'água ainda.'),
      findsOneWidget,
    );
  });
}
