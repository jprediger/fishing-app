import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/services/geocoding_service.dart';

const _json = '''
[
  { "display_name": "Lajeado, Rio Grande do Sul, Brasil", "lat": "-29.4669", "lon": "-51.9611" },
  { "display_name": "Lajeado Grande, Santa Catarina, Brasil", "lat": "-27.0", "lon": "-52.0" }
]
''';

void main() {
  group('GeocodingService', () {
    test('faz parse dos lugares e expõe nome curto', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.url.queryParameters['q'], 'Lajeado');
        return http.Response(
          _json,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeocodingService(client: client);
      final places = await service.search('Lajeado');

      expect(places, hasLength(2));
      expect(places.first.shortName, 'Lajeado');
      expect(places.first.lat, closeTo(-29.4669, 0.0001));
      expect(places.first.lon, closeTo(-51.9611, 0.0001));
    });

    test('query vazia não chama a rede', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('[]', 200);
      });

      final places = await GeocodingService(client: client).search('   ');

      expect(places, isEmpty);
      expect(called, isFalse);
    });

    test('lança ApiException em erro HTTP', () async {
      final client = MockClient((_) async => http.Response('erro', 500));
      await expectLater(
        GeocodingService(client: client).search('Lajeado'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
