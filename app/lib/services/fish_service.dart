import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/fish.dart';
import 'api_exception.dart';

// Reexportado para compatibilidade com quem importa `ApiException` daqui.
export 'api_exception.dart';

/// Acesso ao recurso `/api/fish` do backend.
///
/// O [http.Client] é injetável para permitir testes com um cliente simulado.
class FishService {
  final http.Client _client;
  final String _baseUrl;
  final bool _ownsClient;

  FishService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Busca a lista de peixes (primeira página). O backend retorna um
  /// objeto paginado do Spring, do qual extraímos o campo `content`.
  Future<List<Fish>> fetchFish({int page = 0, int size = 50}) async {
    final uri = Uri.parse('$_baseUrl/api/fish?page=$page&size=$size');

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      throw ApiException('Não foi possível conectar ao servidor em $uri.');
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

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
