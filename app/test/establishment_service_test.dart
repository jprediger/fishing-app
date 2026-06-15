import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/models/establishment.dart';
import 'package:mobile_app/services/establishment_service.dart';

const _listJson = '''
[
  {
    "id": 1,
    "name": "Loja do Pescador",
    "category": "LOJA_PESCA",
    "address": "Rua A, 100 - Centro",
    "phone": "51 99999-0000",
    "lon": -51.20,
    "lat": -30.05,
    "distanceMeters": 320.0,
    "source": "OSM"
  }
]
''';

void main() {
  group('EstablishmentService', () {
    test('monta a query e faz parse da lista', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/establishments');
        expect(request.url.queryParameters['q'], 'pescador');
        expect(request.url.queryParameters['category'], 'LOJA_PESCA');
        expect(request.url.queryParameters['limit'], '100');
        return http.Response(
          _listJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = EstablishmentService(
        client: client,
        baseUrl: 'http://test.local',
      );
      final results = await service.search(
        q: 'pescador',
        category: EstablishmentCategory.lojaPesca,
        limit: 100,
      );

      expect(results, hasLength(1));
      final first = results.first;
      expect(first.name, 'Loja do Pescador');
      expect(first.category, EstablishmentCategory.lojaPesca);
      expect(first.address, 'Rua A, 100 - Centro');
      expect(first.distanceMeters, 320.0);
      expect(first.distanceLabel, '320 m');
      expect(first.location, isNotNull);
    });

    test('omite parâmetros vazios da query', () async {
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = EstablishmentService(
        client: client,
        baseUrl: 'http://test.local',
      );
      await service.search(q: '   ');

      expect(capturedUri.queryParameters.containsKey('q'), isFalse);
      expect(capturedUri.queryParameters.containsKey('category'), isFalse);
    });

    test('lança ApiException em erro HTTP', () async {
      final client = MockClient((_) async => http.Response('erro', 500));
      final service = EstablishmentService(
        client: client,
        baseUrl: 'http://test.local',
      );

      await expectLater(service.search(), throwsA(isA<ApiException>()));
    });
  });
}
