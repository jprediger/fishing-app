import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/catch_record.dart';
import 'api_exception.dart';

/// Acesso ao recurso `/api/catches` do backend.
class CatchService {
  final http.Client _client;
  final String _baseUrl;
  final bool _ownsClient;

  CatchService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<CatchRecord> create(CatchCreateRequest request) async {
    final response = await _post('/api/catches', request.toJson());

    if (response.statusCode == 201 || response.statusCode == 200) {
      return CatchRecord.fromJson(_decode(response));
    }

    if (response.statusCode == 400) {
      throw const ApiException(
        'Dados inválidos. Verifique os campos.',
        statusCode: 400,
      );
    }

    throw ApiException(
      'Erro ao criar registro (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Future<CatchRecord> fetchById(int id) async {
    final response = await _get('/api/catches/$id');
    if (response.statusCode == 200) {
      return CatchRecord.fromJson(_decode(response));
    }

    throw ApiException(
      'Erro ao carregar registro (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Future<List<CatchRecord>> list({String? bbox, int? speciesId}) async {
    final queryParameters = <String, String>{};
    if (bbox != null && bbox.isNotEmpty) {
      queryParameters['bbox'] = bbox;
    }
    if (speciesId != null) {
      queryParameters['speciesId'] = '$speciesId';
    }

    final response = await _get(
      '/api/catches',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Erro ao listar registros (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final content = decoded is Map<String, dynamic>
        ? decoded['content']
        : decoded;
    if (content is! List) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    return content
        .whereType<Map<String, dynamic>>()
        .map(CatchRecord.fromJson)
        .toList();
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParameters);

    try {
      return await _client.get(uri, headers: {'Accept': 'application/json'});
    } catch (_) {
      throw ApiException('Não foi possível conectar ao servidor em $uri.');
    }
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      return await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      throw ApiException('Não foi possível conectar ao servidor em $uri.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada do servidor.');
    }
    return decoded;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
