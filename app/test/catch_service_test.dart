import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/models/catch_record.dart';
import 'package:mobile_app/services/catch_service.dart';

const _createResponse = '''
{
  "id": 99,
  "waterBody": {
    "id": 1,
    "name": "Lago Guaíba",
    "waterType": "LAKE",
    "geometry": {"type": "Polygon", "coordinates": []},
    "osmId": 1001,
    "source": "OSM",
    "centerLon": -51.20,
    "centerLat": -30.08
  },
  "location": {"lat": -30.05, "lon": -50.95},
  "locationVisibility": "EXACT",
  "species": {
    "id": 7,
    "name": "Tucunaré",
    "description": null,
    "region": "Amazônia",
    "type": "FRESHWATER",
    "icon": null
  },
  "fishingMethod": "ARREMESSO",
  "purpose": "SPORT",
  "caughtAt": "2026-06-14T12:00:00Z",
  "photos": []
}
''';

void main() {
  test('serializa o create com ponto e FK resolvidos', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/catches');
      final body = request.body;
      expect(body, contains('"waterBodyId":1'));
      expect(body, contains('"speciesId":7'));
      expect(body, contains('"locationVisibility":"EXACT"'));
      expect(body, contains('"fishingMethod":"ARREMESSO"'));
      expect(body, contains('"purpose":"SPORT"'));
      expect(body, contains('"lat":-30.05'));
      expect(body, contains('"lon":-50.95'));
      return http.Response(
        _createResponse,
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = CatchService(client: client, baseUrl: 'http://test.local');
    final created = await service.create(
      CatchCreateRequest(
        waterBodyId: 1,
        location: const LatLng(-30.05, -50.95),
        locationVisibility: LocationVisibility.exact,
        speciesId: 7,
        fishingMethod: FishingMethod.arremesso,
        purpose: FishingPurpose.sport,
        caughtAt: DateTime.utc(2026, 6, 14, 12),
      ),
    );

    expect(created.id, 99);
    expect(created.waterBody.name, 'Lago Guaíba');
    expect(created.species.name, 'Tucunaré');
    expect(created.location!.latitude, -30.05);
    expect(created.location!.longitude, -50.95);
  });

  test('faz parse de list paginada', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/catches');
      expect(request.url.queryParameters['page'], '0');
      expect(request.url.queryParameters['size'], '50');
      expect(request.url.queryParameters['speciesId'], '7');
      return http.Response(
        jsonEncode({
          'content': [jsonDecode(_createResponse)],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = CatchService(client: client, baseUrl: 'http://test.local');
    final list = await service.list(speciesId: 7);

    expect(list, hasLength(1));
    expect(list.first.id, 99);
  });

  test('sobe fotos como multipart depois do create', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/catches/99/photos');
      expect(request.headers['accept'], 'application/json');
      expect(request.headers['content-type'], contains('multipart/form-data'));
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'filePath': 'photo-1.jpg',
            'position': 0,
            'createdAt': '2026-06-14T12:00:00Z',
          },
        ]),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = CatchService(client: client, baseUrl: 'http://test.local');
    final photos = await service.uploadPhotos(99, [
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'photo-1.jpg',
        mimeType: 'image/jpeg',
      ),
    ]);

    expect(photos, hasLength(1));
    expect(photos.single.filePath, 'photo-1.jpg');
  });
}
