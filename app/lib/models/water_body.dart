import 'package:latlong2/latlong.dart';

/// Tipo de corpo d'água, espelha `WaterType` do backend.
enum WaterType {
  river('RIVER', 'Rio'),
  lake('LAKE', 'Lago'),
  lagoon('LAGOON', 'Lagoa'),
  reservoir('RESERVOIR', 'Reservatório'),
  pond('POND', 'Açude');

  final String apiValue;
  final String label;

  const WaterType(this.apiValue, this.label);

  static WaterType fromApi(String? value) {
    return WaterType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => WaterType.lake,
    );
  }
}

/// Corpo d'água devolvido por `/api/water-bodies`.
class WaterBody {
  final int id;
  final String name;
  final WaterType waterType;
  final Map<String, dynamic> geometry;
  final int? osmId;
  final String? source;
  final double? centerLon;
  final double? centerLat;
  final double? distanceMeters;

  const WaterBody({
    required this.id,
    required this.name,
    required this.waterType,
    required this.geometry,
    this.osmId,
    this.source,
    this.centerLon,
    this.centerLat,
    this.distanceMeters,
  });

  factory WaterBody.fromJson(Map<String, dynamic> json) {
    return WaterBody(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      waterType: WaterType.fromApi(json['waterType'] as String?),
      geometry: Map<String, dynamic>.from(json['geometry'] as Map? ?? const {}),
      osmId: (json['osmId'] as num?)?.toInt(),
      source: json['source'] as String?,
      centerLon: (json['centerLon'] as num?)?.toDouble(),
      centerLat: (json['centerLat'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    );
  }

  LatLng? get centerLocation {
    if (centerLat == null || centerLon == null) return null;
    return LatLng(centerLat!, centerLon!);
  }

  String? get geometryType => geometry['type'] as String?;
}
