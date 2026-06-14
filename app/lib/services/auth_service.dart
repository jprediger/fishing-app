import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';
import 'api_exception.dart';
import 'mock_data.dart';

/// Acesso aos endpoints de autenticação e perfil do backend.
///
/// O [http.Client] é injetável para testes. Em modo mock (`USE_MOCK`, ligado
/// por padrão) usa um cliente simulado que aceita as credenciais de demo,
/// permitindo rodar o app sem o backend no ar.
class AuthService {
  /// Define se o app usa um backend simulado em vez do real.
  static const bool useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);

  final http.Client _client;
  final String _baseUrl;
  final bool _ownsClient;

  AuthService({http.Client? client, String? baseUrl})
      : _client = client ?? (useMock ? createMockClient() : http.Client()),
        _ownsClient = client == null,
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Registra um novo usuário (role USER). `201` em sucesso.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });

    if (response.statusCode == 201 || response.statusCode == 200) return;
    if (response.statusCode == 409) {
      throw const ApiException('Este e-mail já está cadastrado.',
          statusCode: 409);
    }
    if (response.statusCode == 400) {
      throw const ApiException('Dados inválidos. Verifique os campos.',
          statusCode: 400);
    }
    throw ApiException('Não foi possível registrar (${response.statusCode}).',
        statusCode: response.statusCode);
  }

  /// Autentica e retorna a sessão (token + usuário). `401` em credenciais ruins.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      return AuthSession.fromJson(_decode(response));
    }
    if (response.statusCode == 401) {
      throw const ApiException('E-mail ou senha incorretos.', statusCode: 401);
    }
    throw ApiException('Não foi possível entrar (${response.statusCode}).',
        statusCode: response.statusCode);
  }

  /// Busca o usuário autenticado (`GET /api/users/me`).
  Future<AuthUser> me(String token) async {
    final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_baseUrl/api/users/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {
      throw const ApiException('Não foi possível conectar ao servidor.');
    }

    if (response.statusCode == 200) return AuthUser.fromJson(_decode(response));
    if (response.statusCode == 401) {
      throw const ApiException('Sessão expirada.', statusCode: 401);
    }
    throw ApiException('Erro ao carregar perfil (${response.statusCode}).',
        statusCode: response.statusCode);
  }

  /// Atualiza nome e (opcionalmente) senha do usuário autenticado.
  Future<AuthUser> updateMe(
    String token, {
    required String name,
    String? password,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (password != null && password.isNotEmpty) body['password'] = password;

    final http.Response response;
    try {
      response = await _client.put(
        Uri.parse('$_baseUrl/api/users/me'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      throw const ApiException('Não foi possível conectar ao servidor.');
    }

    if (response.statusCode == 200) return AuthUser.fromJson(_decode(response));
    if (response.statusCode == 401) {
      throw const ApiException('Sessão expirada.', statusCode: 401);
    }
    if (response.statusCode == 400) {
      throw const ApiException('Dados inválidos. Verifique os campos.',
          statusCode: 400);
    }
    throw ApiException('Erro ao salvar perfil (${response.statusCode}).',
        statusCode: response.statusCode);
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      throw const ApiException('Não foi possível conectar ao servidor.');
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
