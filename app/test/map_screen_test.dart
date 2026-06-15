import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/screens/map_screen.dart';
import 'package:mobile_app/services/water_body_service.dart';

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

Widget _wrap(WaterBodyService service, {LatLng? draftPoint}) => MaterialApp(
  home: MapScreen(
    waterBodyService: service,
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

      return http.Response(
        _waterBodiesJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
        draftPoint: const LatLng(-30.05, -50.95),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.text('Corpos d\'água'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Marcar ponto'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.text('Lago Guaíba'), findsOneWidget);
    expect(find.textContaining('Criar registro aqui'), findsOneWidget);
  });

  testWidgets('404 desabilita CTA do pin solto', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/water-bodies/nearest') {
        return http.Response('', 404);
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

      return http.Response(
        _waterBodiesJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      _wrap(
        WaterBodyService(client: client, baseUrl: 'http://test.local'),
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
}
