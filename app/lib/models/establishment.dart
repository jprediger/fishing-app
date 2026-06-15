import 'package:latlong2/latlong.dart';

/// Categoria de estabelecimento de pesca, espelha `EstablishmentCategory` do backend.
enum EstablishmentCategory {
  lojaPesca('LOJA_PESCA', 'Loja de pesca'),
  pesqueiro('PESQUEIRO', 'Pesqueiro'),
  iscaria('ISCARIA', 'Iscaria'),
  marina('MARINA', 'Marina'),
  rampa('RAMPA', 'Rampa de barco'),
  clube('CLUBE', 'Clube'),
  outro('OUTRO', 'Outro');

  final String apiValue;
  final String label;

  const EstablishmentCategory(this.apiValue, this.label);

  static EstablishmentCategory fromApi(String? value) {
    return EstablishmentCategory.values.firstWhere(
      (category) => category.apiValue == value,
      orElse: () => EstablishmentCategory.outro,
    );
  }
}

/// Estabelecimento devolvido por `/api/establishments`.
class Establishment {
  final int id;
  final String name;
  final EstablishmentCategory category;
  final String? address;
  final String? phone;
  final double? lon;
  final double? lat;

  /// Distância em metros ao ponto de busca; só vem preenchida quando a busca
  /// informa `lat`/`lon`.
  final double? distanceMeters;
  final String? source;

  const Establishment({
    required this.id,
    required this.name,
    required this.category,
    this.address,
    this.phone,
    this.lon,
    this.lat,
    this.distanceMeters,
    this.source,
  });

  factory Establishment.fromJson(Map<String, dynamic> json) {
    return Establishment(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      category: EstablishmentCategory.fromApi(json['category'] as String?),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      lon: (json['lon'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      source: json['source'] as String?,
    );
  }

  LatLng? get location {
    if (lat == null || lon == null) return null;
    return LatLng(lat!, lon!);
  }

  /// Distância formatada para exibição (ex.: "320 m", "4,2 km").
  String? get distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}
