import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/water_body.dart';
import 'api_exception.dart';
import 'mock_data.dart';

/// Acesso ao recurso `/api/water-bodies` do backend.
class WaterBodyService {
  static const bool useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);

  final http.Client _client;
  final String _baseUrl;

  WaterBodyService({http.Client? client, String? baseUrl})
      : _client = client ?? (useMock ? createMockClient() : http.Client()),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<List<WaterBody>> fetchWaterBodies({String? bbox}) async {
    final uri = Uri.parse('$_baseUrl/api/water-bodies').replace(
      queryParameters: bbox == null || bbox.isEmpty ? null : {'bbox': bbox},
    );

    final http.Response response;
    try {
      response =
          await _client.get(uri, headers: {'Accept': 'application/json'});
    } catch (e) {
      throw const ApiException('Não foi possível conectar ao servidor.');
    }

    if (response.statusCode != 200) {
      throw ApiException('Erro ao buscar corpos d\'água (${response.statusCode}).',
          statusCode: response.statusCode);
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

  void dispose() => _client.close();
}
