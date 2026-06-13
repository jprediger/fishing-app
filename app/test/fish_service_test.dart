import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/models/fish.dart';
import 'package:mobile_app/services/fish_service.dart';
import 'package:mobile_app/services/mock_data.dart';

const _pageJson = '''
{
  "content": [
    {
      "id": 1,
      "name": "Tucunaré",
      "description": "Peixe predador de água doce",
      "region": "Bacia Amazônica",
      "type": "FRESHWATER",
      "icon": { "path": "/icons/tucunare.png" }
    },
    {
      "id": 2,
      "name": "Robalo",
      "description": null,
      "region": "Litoral",
      "type": "SALTWATER",
      "icon": null
    }
  ],
  "totalElements": 2,
  "totalPages": 1
}
''';

void main() {
  group('FishService', () {
    test('faz parse do Page do Spring e retorna a lista de peixes', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/fish');
        expect(request.url.queryParameters['page'], '0');
        return http.Response(_pageJson, 200,
            headers: {'content-type': 'application/json'});
      });

      final service =
          FishService(client: client, baseUrl: 'http://test.local');
      final fish = await service.fetchFish();

      expect(fish, hasLength(2));
      expect(fish.first.name, 'Tucunaré');
      expect(fish.first.type, FishType.freshwater);
      expect(fish.first.iconPath, '/icons/tucunare.png');
      expect(fish[1].type, FishType.saltwater);
      expect(fish[1].iconPath, isNull);
    });

    test('lança ApiException em status de erro', () async {
      final client = MockClient((request) async => http.Response('erro', 500));
      final service =
          FishService(client: client, baseUrl: 'http://test.local');

      expect(service.fetchFish(), throwsA(isA<ApiException>()));
    });

    test('lança ApiException quando não consegue conectar', () async {
      final client = MockClient((request) async => throw Exception('offline'));
      final service =
          FishService(client: client, baseUrl: 'http://test.local');

      expect(service.fetchFish(), throwsA(isA<ApiException>()));
    });

    test('modo mock retorna o catálogo completo de peixes', () async {
      final service = FishService(client: createMockClient());
      final fish = await service.fetchFish();

      expect(fish, hasLength(6));
      expect(fish.map((f) => f.name), contains('Tucunaré'));
      expect(fish.any((f) => f.type == FishType.brackish), isTrue);
    });
  });
}
