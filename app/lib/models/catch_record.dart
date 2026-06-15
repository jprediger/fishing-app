import 'package:latlong2/latlong.dart';

import 'fish.dart';
import 'water_body.dart';

enum LocationVisibility {
  exact('EXACT', 'Exato'),
  riverOnly('RIVER_ONLY', 'Somente o rio');

  final String apiValue;
  final String label;

  const LocationVisibility(this.apiValue, this.label);

  static LocationVisibility fromApi(String? value) {
    return LocationVisibility.values.firstWhere(
      (option) => option.apiValue == value,
      orElse: () => LocationVisibility.exact,
    );
  }
}

enum FishingPurpose {
  sport('SPORT', 'Esportiva'),
  consumption('CONSUMPTION', 'Consumo');

  final String apiValue;
  final String label;

  const FishingPurpose(this.apiValue, this.label);

  static FishingPurpose fromApi(String? value) {
    return FishingPurpose.values.firstWhere(
      (option) => option.apiValue == value,
      orElse: () => FishingPurpose.sport,
    );
  }
}

enum FishingMethod {
  arremesso('ARREMESSO', 'Arremesso'),
  fly('FLY', 'Fly'),
  corrico('CORRICO', 'Corrico'),
  fundo('FUNDO', 'Fundo'),
  boia('BOIA', 'Boia'),
  outro('OUTRO', 'Outro');

  final String apiValue;
  final String label;

  const FishingMethod(this.apiValue, this.label);

  static FishingMethod fromApi(String? value) {
    return FishingMethod.values.firstWhere(
      (option) => option.apiValue == value,
      orElse: () => FishingMethod.outro,
    );
  }
}

enum WeatherCondition {
  clear('CLEAR', 'Céu aberto'),
  partlyCloudy('PARTLY_CLOUDY', 'Parcialmente nublado'),
  cloudy('CLOUDY', 'Nublado'),
  fog('FOG', 'Neblina'),
  drizzle('DRIZZLE', 'Chuvisco'),
  rain('RAIN', 'Chuva'),
  snow('SNOW', 'Neve'),
  thunderstorm('THUNDERSTORM', 'Tempestade');

  final String apiValue;
  final String label;

  const WeatherCondition(this.apiValue, this.label);

  static WeatherCondition fromApi(String? value) {
    return WeatherCondition.values.firstWhere(
      (option) => option.apiValue == value,
      orElse: () => WeatherCondition.clear,
    );
  }
}

class CatchPhoto {
  final int? id;
  final String filePath;
  final int? position;
  final DateTime? createdAt;

  const CatchPhoto({
    this.id,
    required this.filePath,
    this.position,
    this.createdAt,
  });

  factory CatchPhoto.fromJson(Map<String, dynamic> json) {
    return CatchPhoto(
      id: (json['id'] as num?)?.toInt(),
      filePath: json['filePath'] as String,
      position: (json['position'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class CatchAuthor {
  final int id;
  final String name;
  final String? avatarPath;

  const CatchAuthor({required this.id, required this.name, this.avatarPath});

  factory CatchAuthor.fromJson(Map<String, dynamic> json) {
    return CatchAuthor(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      avatarPath: json['avatarPath'] as String?,
    );
  }
}

class CatchWeather {
  final double? temperatureC;
  final WeatherCondition? condition;
  final double? windSpeedKmh;
  final int? windDirectionDeg;
  final int? humidityPct;
  final double? pressureHpa;
  final int? code;
  final DateTime? capturedAt;
  final String? source;

  const CatchWeather({
    this.temperatureC,
    this.condition,
    this.windSpeedKmh,
    this.windDirectionDeg,
    this.humidityPct,
    this.pressureHpa,
    this.code,
    this.capturedAt,
    this.source,
  });

  factory CatchWeather.fromJson(Map<String, dynamic> json) {
    return CatchWeather(
      temperatureC: (json['temperatureC'] as num?)?.toDouble(),
      condition: json['condition'] == null
          ? null
          : WeatherCondition.fromApi(json['condition'] as String?),
      windSpeedKmh: (json['windSpeedKmh'] as num?)?.toDouble(),
      windDirectionDeg: (json['windDirectionDeg'] as num?)?.toInt(),
      humidityPct: (json['humidityPct'] as num?)?.toInt(),
      pressureHpa: (json['pressureHpa'] as num?)?.toDouble(),
      code: (json['code'] as num?)?.toInt(),
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? ''),
      source: json['source'] as String?,
    );
  }
}

class CatchRecord {
  final int id;
  final WaterBody waterBody;
  final LatLng? location;
  final LocationVisibility locationVisibility;
  final Fish species;
  final int? weightGrams;
  final int? lengthMm;
  final String? description;
  final FishingMethod fishingMethod;
  final FishingPurpose purpose;
  final DateTime caughtAt;
  final List<CatchPhoto> photos;
  final CatchWeather? weather;
  final bool shared;
  final bool mine;
  final CatchAuthor? author;

  const CatchRecord({
    required this.id,
    required this.waterBody,
    required this.location,
    required this.locationVisibility,
    required this.species,
    this.weightGrams,
    this.lengthMm,
    this.description,
    required this.fishingMethod,
    required this.purpose,
    required this.caughtAt,
    this.photos = const [],
    this.weather,
    this.shared = true,
    this.mine = false,
    this.author,
  });

  factory CatchRecord.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    return CatchRecord(
      id: (json['id'] as num).toInt(),
      waterBody: WaterBody.fromJson(json['waterBody'] as Map<String, dynamic>),
      location: location == null
          ? null
          : LatLng(
              (location['lat'] as num?)?.toDouble() ?? 0,
              (location['lon'] as num?)?.toDouble() ?? 0,
            ),
      locationVisibility: LocationVisibility.fromApi(
        json['locationVisibility'] as String?,
      ),
      species: Fish.fromJson(json['species'] as Map<String, dynamic>),
      weightGrams: (json['weightGrams'] as num?)?.toInt(),
      lengthMm: (json['lengthMm'] as num?)?.toInt(),
      description: json['description'] as String?,
      fishingMethod: FishingMethod.fromApi(json['fishingMethod'] as String?),
      purpose: FishingPurpose.fromApi(json['purpose'] as String?),
      caughtAt: DateTime.parse(json['caughtAt'] as String),
      photos: (json['photos'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CatchPhoto.fromJson)
          .toList(),
      weather:
          json['weather'] is Map<String, dynamic> &&
              (json['weather'] as Map<String, dynamic>).isNotEmpty
          ? CatchWeather.fromJson(json['weather'] as Map<String, dynamic>)
          : null,
      shared: json['shared'] as bool? ?? true,
      mine: json['mine'] as bool? ?? false,
      author: json['author'] is Map<String, dynamic>
          ? CatchAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CatchCreateRequest {
  final int waterBodyId;
  final LatLng location;
  final LocationVisibility locationVisibility;
  final int speciesId;
  final int? weightGrams;
  final int? lengthMm;
  final String? description;
  final FishingMethod fishingMethod;
  final FishingPurpose purpose;
  final DateTime caughtAt;
  final bool shared;

  const CatchCreateRequest({
    required this.waterBodyId,
    required this.location,
    required this.locationVisibility,
    required this.speciesId,
    this.weightGrams,
    this.lengthMm,
    this.description,
    required this.fishingMethod,
    required this.purpose,
    required this.caughtAt,
    this.shared = true,
  });

  Map<String, dynamic> toJson() => {
    'waterBodyId': waterBodyId,
    'location': {'lat': location.latitude, 'lon': location.longitude},
    'locationVisibility': locationVisibility.apiValue,
    'speciesId': speciesId,
    if (weightGrams != null) 'weightGrams': weightGrams,
    if (lengthMm != null) 'lengthMm': lengthMm,
    if (description != null && description!.trim().isNotEmpty)
      'description': description,
    'fishingMethod': fishingMethod.apiValue,
    'purpose': purpose.apiValue,
    'caughtAt': caughtAt.toUtc().toIso8601String(),
    'shared': shared,
  };
}
