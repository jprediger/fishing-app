import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/fish.dart';
import 'mock_data.dart';

/// Erro lançado quando uma chamada ao backend falha.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Acesso ao recurso `/api/fish` do backend.
///
/// O [http.Client] é injetável para permitir testes com um cliente simulado.
///
/// Por padrão o app roda em modo mock (sem precisar do backend no ar). Para
/// apontar para o backend real, rode com:
/// `flutter run --dart-define=USE_MOCK=false`
class FishService {
  /// Define se o app usa dados mockados em vez do backend real.
  static const bool useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);

  final http.Client _client;
  final String _baseUrl;

  FishService({http.Client? client, String? baseUrl})
      : _client = client ?? (useMock ? createMockClient() : http.Client()),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Busca a lista de peixes (primeira página). O backend retorna um
  /// objeto paginado do Spring, do qual extraímos o campo `content`.
  Future<List<Fish>> fetchFish({int page = 0, int size = 50}) async {
    final uri = Uri.parse('$_baseUrl/api/fish?page=$page&size=$size');

    final http.Response response;
    try {
      response = await _client.get(uri, headers: {'Accept': 'application/json'});
    } catch (e) {
      throw ApiException('Não foi possível conectar ao servidor.');
    }

    if (response.statusCode != 200) {
      throw ApiException('Erro ao buscar peixes (${response.statusCode}).');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final content = decoded is Map<String, dynamic> ? decoded['content'] : null;
    if (content is! List) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    return content
        .whereType<Map<String, dynamic>>()
        .map(Fish.fromJson)
        .toList();
  }

  void dispose() => _client.close();
}
