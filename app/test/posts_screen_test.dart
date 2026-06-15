// Testes de widget da aba Posts: feed por região alimentado pelo backend
// simulado e busca de local via geocoder simulado.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/screens/posts_screen.dart';
import 'package:mobile_app/services/catch_service.dart';
import 'package:mobile_app/services/geocoding_service.dart';

const _catchPageJson = '''
{
  "content": [
    {
      "id": 1,
      "species": { "id": 1, "name": "Traíra", "type": "FRESHWATER", "icon": null },
      "waterBody": {
        "id": 4, "name": "Lago Guaíba", "waterType": "LAKE",
        "geometry": { "type": "Point", "coordinates": [-51.2, -30.0] },
        "centerLon": -51.2, "centerLat": -30.0
      },
      "location": { "lat": -30.0, "lon": -51.2 },
      "locationVisibility": "EXACT",
      "weightGrams": 1200,
      "lengthMm": 350,
      "description": "bela traíra",
      "fishingMethod": "ARREMESSO",
      "purpose": "SPORT",
      "caughtAt": "2026-06-10T12:00:00Z",
      "photos": [],
      "mine": false
    }
  ],
  "totalElements": 1,
  "totalPages": 1
}
''';

CatchService _catchService() => CatchService(
  baseUrl: 'http://test.local',
  client: MockClient((request) async {
    expect(request.url.path, '/api/catches');
    return http.Response(
      _catchPageJson,
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

GeocodingService _geocoder() =>
    GeocodingService(client: MockClient((_) async => http.Response('[]', 200)));

void main() {
  testWidgets('carrega o feed da região padrão', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PostsScreen(
          catchService: _catchService(),
          geocodingService: _geocoder(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Rio Grande do Sul'), findsOneWidget);
    expect(find.text('Traíra'), findsOneWidget);
  });

  testWidgets('busca de local atualiza a região', (tester) async {
    final geocoder = GeocodingService(
      client: MockClient(
        (_) async => http.Response(
          '[{"display_name":"Lajeado, RS, Brasil","lat":"-29.46","lon":"-51.96"}]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PostsScreen(
          catchService: _catchService(),
          geocodingService: geocoder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Lajeado');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // Região passou a refletir o local buscado (rótulo + texto do campo).
    expect(find.text('Lajeado'), findsWidgets);
    // Botão "Limpar" aparece quando há uma região buscada ativa.
    expect(find.text('Limpar'), findsOneWidget);
  });
}
