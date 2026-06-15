import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';
import '../models/auth_user.dart';

/// Abstração mínima de armazenamento chave-valor, para permitir um fake
/// em testes (o `flutter_secure_storage` depende de canais de plataforma).
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Implementação real, sobre o `flutter_secure_storage`.
class SecureKeyValueStore implements KeyValueStore {
  final FlutterSecureStorage _storage;

  SecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Persiste e recupera a sessão (token + usuário) de forma segura.
class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _expiresKey = 'auth_expires_in';
  static const _userKey = 'auth_user';

  final KeyValueStore _store;

  TokenStorage({KeyValueStore? store})
    : _store = store ?? SecureKeyValueStore();

  /// Salva a sessão completa.
  Future<void> save(AuthSession session) async {
    await _store.write(_tokenKey, session.token);
    await _store.write(_expiresKey, session.expiresIn.toString());
    await _store.write(_userKey, jsonEncode(session.user.toJson()));
  }

  /// Lê a sessão salva, ou `null` se não houver token/usuário.
  Future<AuthSession?> read() async {
    final token = await _store.read(_tokenKey);
    final userJson = await _store.read(_userKey);
    if (token == null || token.isEmpty || userJson == null) return null;

    final expiresIn = int.tryParse(await _store.read(_expiresKey) ?? '') ?? 0;
    final decoded = jsonDecode(userJson) as Map<String, dynamic>;
    return AuthSession(
      token: token,
      expiresIn: expiresIn,
      user: AuthUser.fromJson(decoded),
    );
  }

  /// Atualiza apenas o usuário salvo (mantém o token).
  Future<void> saveUser(AuthUser user) async {
    await _store.write(_userKey, jsonEncode(user.toJson()));
  }

  /// Limpa toda a sessão (logout).
  Future<void> clear() async {
    await _store.delete(_tokenKey);
    await _store.delete(_expiresKey);
    await _store.delete(_userKey);
  }
}
