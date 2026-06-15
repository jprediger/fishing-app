import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile_app/models/catch_record.dart';
import 'package:mobile_app/screens/catch_detail_screen.dart';
import 'package:mobile_app/services/catch_service.dart';

CatchRecord _sampleRecord() {
  return CatchRecord.fromJson({
    'id': 1,
    'author': {'id': 11, 'name': 'Ana', 'avatarPath': 'avatars/ana.webp'},
    'species': {
      'id': 7,
      'name': 'Tucunaré',
      'description': null,
      'region': 'RS',
      'type': 'FRESHWATER',
      'icon': null,
    },
    'waterBody': {
      'id': 1,
      'name': 'Lago Guaíba',
      'waterType': 'LAKE',
      'geometry': {'type': 'Polygon', 'coordinates': []},
      'osmId': 1001,
      'source': 'OSM',
      'centerLon': -51.2,
      'centerLat': -30.08,
      'catchCount': 21,
    },
    'location': {'lat': -30.08, 'lon': -51.2},
    'locationVisibility': 'EXACT',
    'weightGrams': 1200,
    'lengthMm': 450,
    'description': 'Boa captura',
    'fishingMethod': 'ARREMESSO',
    'purpose': 'SPORT',
    'caughtAt': '2026-06-14T12:00:00Z',
    'photos': const [],
    'mine': false,
  });
}

void main() {
  testWidgets('mostra avatar real do autor quando disponível', (tester) async {
    final service = CatchService(
      client: MockClient((_) async => throw Exception('not used')),
      baseUrl: 'http://test.local',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CatchDetailScreen(
          initialRecord: _sampleRecord(),
          catchService: service,
          authToken: 'jwt-123',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsWidgets);
    expect(find.byType(Image), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      'http://test.local/uploads/avatars/ana.webp',
    );
  });
}
