import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/water_body.dart';
import 'api_exception.dart';

/// Acesso ao recurso `/api/water-bodies` do backend.
class WaterBodyService {
  final http.Client _client;
  final String _baseUrl;
  final bool _ownsClient;

  WaterBodyService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<List<WaterBody>> fetchWaterBodies({String? bbox, int? zoom}) async {
    final queryParameters = <String, String>{};
    if (bbox != null && bbox.isNotEmpty) {
      queryParameters['bbox'] = bbox;
    }
    if (zoom != null) {
      queryParameters['zoom'] = '$zoom';
    }

    final uri = Uri.parse('$_baseUrl/api/water-bodies').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      throw const ApiException('Não foi possível conectar ao servidor.');
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'Erro ao buscar corpos d\'água (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(WaterBody.fromJson)
        .toList();
  }

  Future<WaterBody?> fetchNearest({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/water-bodies/nearest',
    ).replace(queryParameters: {'lat': '$lat', 'lon': '$lon'});

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      throw const ApiException('Não foi possível conectar ao servidor.');
    }

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Erro ao buscar corpo d\'água mais próximo (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    return WaterBody.fromJson(decoded);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
