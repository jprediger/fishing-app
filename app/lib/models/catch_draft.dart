import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'catch_record.dart';
import 'fish.dart';
import 'water_body.dart';

/// Estado mutável do wizard de criação/edição de uma pesca.
class CatchDraft extends ChangeNotifier {
  final LatLng point;
  final WaterBody waterBody;

  Fish? species;
  final List<XFile> photos;
  DateTime caughtAt;
  LocationVisibility locationVisibility;
  FishingMethod fishingMethod;
  FishingPurpose purpose;
  int? weightGrams;
  int? lengthMm;
  String? description;

  /// Quando false, a pesca fica privada (não é compartilhada nos feeds).
  bool shared;

  CatchDraft({
    required this.point,
    required this.waterBody,
    this.species,
    List<XFile>? photos,
    DateTime? caughtAt,
    LocationVisibility? locationVisibility,
    FishingMethod? fishingMethod,
    FishingPurpose? purpose,
    this.weightGrams,
    this.lengthMm,
    this.description,
    bool? shared,
  }) : photos = List<XFile>.from(photos ?? const []),
       caughtAt = caughtAt ?? DateTime.now(),
       locationVisibility = locationVisibility ?? LocationVisibility.exact,
       fishingMethod = fishingMethod ?? FishingMethod.arremesso,
       purpose = purpose ?? FishingPurpose.sport,
       shared = shared ?? true;

  factory CatchDraft.fromRecord(CatchRecord record) {
    return CatchDraft(
      point:
          record.location ??
          record.waterBody.centerLocation ??
          const LatLng(-30.0846, -51.2645),
      waterBody: record.waterBody,
      species: record.species,
      photos: const [],
      caughtAt: record.caughtAt,
      locationVisibility: record.locationVisibility,
      fishingMethod: record.fishingMethod,
      purpose: record.purpose,
      weightGrams: record.weightGrams,
      lengthMm: record.lengthMm,
      description: record.description,
      shared: record.shared,
    );
  }

  void setSpecies(Fish? value) {
    species = value;
    notifyListeners();
  }

  void setCaughtAt(DateTime value) {
    caughtAt = value;
    notifyListeners();
  }

  void setLocationVisibility(LocationVisibility value) {
    locationVisibility = value;
    notifyListeners();
  }

  void setFishingMethod(FishingMethod value) {
    fishingMethod = value;
    notifyListeners();
  }

  void setPurpose(FishingPurpose value) {
    purpose = value;
    notifyListeners();
  }

  void setWeight(String? value) {
    weightGrams = int.tryParse((value ?? '').trim());
    notifyListeners();
  }

  void setLength(String? value) {
    lengthMm = int.tryParse((value ?? '').trim());
    notifyListeners();
  }

  void setDescription(String? value) {
    description = value;
    notifyListeners();
  }

  void setShared(bool value) {
    shared = value;
    notifyListeners();
  }

  void addPhotos(Iterable<XFile> value) {
    photos.addAll(value);
    notifyListeners();
  }

  void removePhotoAt(int index) {
    photos.removeAt(index);
    notifyListeners();
  }

  bool get canContinueFromStep1 => species != null && photos.isNotEmpty;

  CatchCreateRequest toRequest() {
    final species = this.species;
    if (species == null) {
      throw StateError('Species is required');
    }

    return CatchCreateRequest(
      waterBodyId: waterBody.id,
      location: point,
      locationVisibility: locationVisibility,
      speciesId: species.id,
      weightGrams: weightGrams,
      lengthMm: lengthMm,
      description: description,
      fishingMethod: fishingMethod,
      purpose: purpose,
      caughtAt: caughtAt.toUtc(),
      shared: shared,
    );
  }
}
