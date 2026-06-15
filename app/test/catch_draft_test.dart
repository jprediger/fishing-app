import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/models/catch_draft.dart';
import 'package:mobile_app/models/catch_record.dart';
import 'package:mobile_app/models/fish.dart';
import 'package:mobile_app/models/water_body.dart';

void main() {
  test('mantém seleção entre etapas e gera request', () async {
    final draft = CatchDraft(
      point: const LatLng(-30.05, -50.95),
      waterBody: const WaterBody(
        id: 1,
        name: 'Lago Guaíba',
        waterType: WaterType.lake,
        geometry: {},
      ),
    );

    expect(draft.canContinueFromStep1, isFalse);
    draft.setSpecies(
      const Fish(id: 7, name: 'Tucunaré', type: FishType.freshwater),
    );
    draft.addPhotos([
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'one.jpg',
        mimeType: 'image/jpeg',
      ),
    ]);

    expect(draft.canContinueFromStep1, isTrue);
    final request = draft.toRequest();
    expect(request.waterBodyId, 1);
    expect(request.speciesId, 7);
    expect(request.locationVisibility, LocationVisibility.exact);
    expect(request.fishingMethod, FishingMethod.arremesso);
    expect(request.purpose, FishingPurpose.sport);
  });
}
