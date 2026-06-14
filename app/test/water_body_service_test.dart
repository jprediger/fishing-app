import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/models/water_body.dart';
import 'package:mobile_app/services/api_exception.dart';
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
        expect(request.url.queryParameters['zoom'], '11');
        return http.Response(
          _listJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = WaterBodyService(
        client: client,
        baseUrl: 'http://test.local',
      );
      final waterBodies = await service.fetchWaterBodies(
        bbox: '-51,-30,-50,-29',
        zoom: 11,
      );

      expect(waterBodies, hasLength(1));
      expect(waterBodies.first.name, 'Lago Guaíba');
      expect(waterBodies.first.waterType, WaterType.lake);
      expect(waterBodies.first.geometry['type'], 'Polygon');
    });

    test('lança ApiException em erro HTTP', () async {
      final client = MockClient((_) async => http.Response('erro', 500));
      final service = WaterBodyService(
        client: client,
        baseUrl: 'http://test.local',
      );

      await expectLater(
        service.fetchWaterBodies(),
        throwsA(isA<ApiException>()),
      );
    });

    test('faz parse do nearest e retorna null em 404', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/water-bodies/nearest');
        expect(request.url.queryParameters['lat'], '-30.05');
        expect(request.url.queryParameters['lon'], '-50.95');
        return http.Response(
          '''
          {
            "id": 1,
            "name": "Lago Guaíba",
            "waterType": "LAKE",
            "geometry": {"type":"Polygon","coordinates":[]},
            "osmId": 123,
            "source": "OSM",
            "centerLon": -50.9,
            "centerLat": -30.05,
            "distanceMeters": 321.0
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = WaterBodyService(
        client: client,
        baseUrl: 'http://test.local',
      );
      final waterBody = await service.fetchNearest(lat: -30.05, lon: -50.95);

      expect(waterBody, isNotNull);
      expect(waterBody!.distanceMeters, 321.0);

      final missingClient = MockClient((_) async => http.Response('', 404));
      final missingService = WaterBodyService(
        client: missingClient,
        baseUrl: 'http://test.local',
      );
      await expectLater(
        missingService.fetchNearest(lat: -30.05, lon: -50.95),
        completion(isNull),
      );
    });
  });
}
