import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
    final response = await _sendJson('POST', '/api/catches', request.toJson());
    return CatchRecord.fromJson(_decodeObject(response));
  }

  Future<CatchRecord> update(int id, CatchCreateRequest request) async {
    final response = await _sendJson(
      'PUT',
      '/api/catches/$id',
      request.toJson(),
    );
    return CatchRecord.fromJson(_decodeObject(response));
  }

  Future<void> delete(int id) async {
    final response = await _request('DELETE', '/api/catches/$id');
    if (response.statusCode != 204) {
      throw ApiException(
        'Erro ao remover registro (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }

  Future<CatchRecord> fetchById(int id) async {
    final response = await _get('/api/catches/$id');
    return CatchRecord.fromJson(_decodeObject(response));
  }

  Future<List<CatchRecord>> list({
    String? bbox,
    int? speciesId,
    int page = 0,
    int size = 50,
  }) async {
    final queryParameters = <String, String>{};
    queryParameters['page'] = '$page';
    queryParameters['size'] = '$size';
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

    return _decodePage(response);
  }

  Future<List<CatchRecord>> listByWaterBody({
    required int waterBodyId,
    int page = 0,
    int size = 20,
  }) async {
    final queryParameters = <String, String>{
      'page': '$page',
      'size': '$size',
      'waterBodyId': '$waterBodyId',
      'sort': 'createdAt,desc',
    };

    final response = await _get(
      '/api/catches',
      queryParameters: queryParameters,
    );

    return _decodePage(response);
  }

  Future<List<CatchRecord>> mine({
    String? bbox,
    int? speciesId,
    int page = 0,
    int size = 50,
  }) async {
    final queryParameters = <String, String>{};
    queryParameters['page'] = '$page';
    queryParameters['size'] = '$size';
    if (bbox != null && bbox.isNotEmpty) {
      queryParameters['bbox'] = bbox;
    }
    if (speciesId != null) {
      queryParameters['speciesId'] = '$speciesId';
    }

    final response = await _get(
      '/api/catches/mine',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    return _decodePage(response);
  }

  Future<List<CatchPhoto>> uploadPhotos(int catchId, List<XFile> files) async {
    if (files.isEmpty) return const [];

    final uri = Uri.parse('$_baseUrl/api/catches/$catchId/photos');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json';

    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          await file.readAsBytes(),
          filename: file.name,
        ),
      );
    }

    final response = await _sendMultipart(request);
    final decoded = _decodeJson(response);
    final list = decoded is Map<String, dynamic> ? decoded['content'] : decoded;
    if (list is! List) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(CatchPhoto.fromJson)
        .toList();
  }

  Future<void> deletePhoto(int catchId, int photoId) async {
    final response = await _request(
      'DELETE',
      '/api/catches/$catchId/photos/$photoId',
    );
    if (response.statusCode != 204) {
      throw ApiException(
        'Erro ao remover foto (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }

  String uploadUrl(String relativePath) {
    final sanitized = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    return '$_baseUrl/uploads/$sanitized';
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

  Future<http.Response> _sendJson(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _request(method, path, body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return response;
    }
    if (response.statusCode == 400) {
      throw const ApiException(
        'Dados inválidos. Verifique os campos.',
        statusCode: 400,
      );
    }
    throw ApiException(
      'Erro ao salvar registro (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final request = http.Request(method, uri)
        ..headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('Não foi possível conectar ao servidor em $uri.');
    }
  }

  Future<http.Response> _sendMultipart(http.MultipartRequest request) async {
    try {
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException(
        'Não foi possível conectar ao servidor em ${request.url}.',
      );
    }
  }

  List<CatchRecord> _decodePage(http.Response response) {
    if (response.statusCode != 200) {
      throw ApiException(
        'Erro ao listar registros (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    final decoded = _decodeJson(response);
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

  dynamic _decodeJson(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded;
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = _decodeJson(response);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada do servidor.');
    }
    return decoded;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
