import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/models/water_body.dart';
import 'package:mobile_app/services/api_exception.dart';
import 'package:mobile_app/services/mock_data.dart';
import 'package:mobile_app/services/water_body_service.dart';

const _listJson = '''
[
  {
    "id": 1,
    "name": "Lago Guaíba",
    "waterType": "LAKE",
    "geometry": {
      "type": "Polygon",
      "coordinates": [[[ -51.0, -30.0 ], [ -50.9, -30.1 ], [ -50.8, -30.0 ], [ -51.0, -30.0 ]]]
    },
    "osmId": 123,
    "source": "OSM",
    "centerLon": -50.9,
    "centerLat": -30.05
  }
]
''';

void main() {
  group('WaterBodyService', () {
    test('faz parse da lista retornada pelo backend', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/water-bodies');
        expect(request.url.queryParameters['bbox'], '-51,-30,-50,-29');
        return http.Response(_listJson, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = WaterBodyService(client: client, baseUrl: 'http://test.local');
      final waterBodies = await service.fetchWaterBodies(bbox: '-51,-30,-50,-29');

      expect(waterBodies, hasLength(1));
      expect(waterBodies.first.name, 'Lago Guaíba');
      expect(waterBodies.first.waterType, WaterType.lake);
      expect(waterBodies.first.geometry['type'], 'Polygon');
    });

    test('lança ApiException em erro HTTP', () async {
      final client = MockClient((_) async => http.Response('erro', 500));
      final service = WaterBodyService(client: client, baseUrl: 'http://test.local');

      await expectLater(
        service.fetchWaterBodies(),
        throwsA(isA<ApiException>()),
      );
    });

    test('modo mock retorna corpos d\'água do mapa', () async {
      final service = WaterBodyService(client: createMockClient());
      final waterBodies = await service.fetchWaterBodies();

      expect(waterBodies, hasLength(3));
      expect(waterBodies.map((body) => body.name), contains('Rio Jacuí'));
    });
  });
}
