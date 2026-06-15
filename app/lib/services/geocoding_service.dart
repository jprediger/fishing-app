import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

// Reexportado para compatibilidade com quem importa `ApiException` daqui.
export 'api_exception.dart';

/// Lugar resolvido pelo geocoder (nome + coordenada do centro).
class GeoPlace {
  final String displayName;
  final double lat;
  final double lon;

  const GeoPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  /// Nome curto para exibição (primeiro segmento do display_name do OSM).
  String get shortName => displayName.split(',').first.trim();
}

/// Geocodificação de nomes de lugares via Nominatim (OpenStreetMap).
///
/// Usado pela aba de Posts para resolver uma cidade/local (ex.: "Lajeado")
/// num ponto, a partir do qual o feed monta a região de busca.
class GeocodingService {
  static const String _host = 'nominatim.openstreetmap.org';

  final http.Client _client;
  final bool _ownsClient;

  GeocodingService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  Future<List<GeoPlace>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final uri = Uri.https(_host, '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '5',
      'countrycodes': 'br',
      'addressdetails': '0',
    });

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          // Nominatim exige um User-Agent identificável.
          'User-Agent': 'fishing-app/1.0',
        },
      );
    } catch (_) {
      throw const ApiException('Não foi possível buscar o local.');
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'Erro ao buscar local (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const ApiException('Resposta inesperada do geocoder.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => GeoPlace(
            displayName: json['display_name'] as String? ?? q,
            lat: double.tryParse('${json['lat']}') ?? 0,
            lon: double.tryParse('${json['lon']}') ?? 0,
          ),
        )
        .where((place) => place.lat != 0 || place.lon != 0)
        .toList();
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
