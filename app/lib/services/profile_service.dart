import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_profile.dart';
import 'api_exception.dart';

class ProfileService {
  final http.Client _client;
  final String _baseUrl;
  final bool _ownsClient;

  ProfileService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<UserProfile> fetchProfile(String token, int userId) async {
    final uri = Uri.parse('$_baseUrl/api/users/$userId');
    final response = await _get(uri, token: token);

    if (response.statusCode != 200) {
      throw ApiException(
        'Erro ao carregar perfil (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada do servidor.');
    }
    return UserProfile.fromJson(decoded);
  }

  Future<http.Response> _get(Uri uri, {required String token}) async {
    try {
      return await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {
      throw ApiException('Não foi possível conectar ao servidor em $uri.');
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
