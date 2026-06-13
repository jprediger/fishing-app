/// Habitat do peixe, espelha o enum `FishType` do backend.
enum FishType {
  freshwater('FRESHWATER', 'Água doce'),
  saltwater('SALTWATER', 'Água salgada'),
  brackish('BRACKISH', 'Água salobra');

  final String apiValue;
  final String label;

  const FishType(this.apiValue, this.label);

  static FishType fromApi(String? value) {
    return FishType.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => FishType.freshwater,
    );
  }
}

/// Espécie de peixe retornada pelo endpoint `/api/fish`.
class Fish {
  final int id;
  final String name;
  final String? description;
  final String? region;
  final FishType type;
  final String? iconPath;

  const Fish({
    required this.id,
    required this.name,
    this.description,
    this.region,
    required this.type,
    this.iconPath,
  });

  factory Fish.fromJson(Map<String, dynamic> json) {
    final icon = json['icon'];
    return Fish(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      region: json['region'] as String?,
      type: FishType.fromApi(json['type'] as String?),
      iconPath: icon is Map<String, dynamic> ? icon['path'] as String? : null,
    );
  }
}
