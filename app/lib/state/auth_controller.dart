import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/auth_session.dart';
import '../models/auth_user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

/// Estado de sessão do app.
enum AuthStatus {
  /// Ainda lendo o storage na abertura (mostra splash).
  unknown,

  /// Sem sessão válida — mostra login/registro.
  unauthenticated,

  /// Sessão ativa — mostra o app.
  authenticated,
}

/// Fonte da verdade da sessão. Criado no `main.dart` e repassado às telas.
///
/// Mantém o estilo do app (sem provider/riverpod): um [ChangeNotifier]
/// injetado abaixo. Expõe o token para o `AuthHttpClient` via [token].
class AuthController extends ChangeNotifier {
  final AuthService _authService;
  final TokenStorage _storage;

  AuthStatus _status = AuthStatus.unknown;
  AuthSession? _session;
  bool _busy = false;
  String? _error;

  AuthController({AuthService? authService, TokenStorage? storage})
    : _authService = authService ?? AuthService(),
      _storage = storage ?? TokenStorage();

  AuthStatus get status => _status;
  AuthUser? get user => _session?.user;
  String? get token => _session?.token;

  /// Verdadeiro durante uma chamada de rede (login/registro/perfil).
  bool get busy => _busy;

  /// Mensagem amigável do último erro, ou `null`.
  String? get error => _error;

  /// Lê a sessão salva na abertura do app e define o estado inicial.
  Future<void> bootstrap() async {
    final session = await _storage.read();
    _session = session;
    _status = session != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Autentica e persiste a sessão. Retorna `true` em sucesso.
  Future<bool> login(String email, String password) {
    return _run(() async {
      final session = await _authService.login(
        email: email,
        password: password,
      );
      await _storage.save(session);
      _session = session;
      _status = AuthStatus.authenticated;
    });
  }

  /// Registra e, em sucesso, faz auto-login. Retorna `true` em sucesso.
  Future<bool> register(String name, String email, String password) {
    return _run(() async {
      await _authService.register(name: name, email: email, password: password);
      final session = await _authService.login(
        email: email,
        password: password,
      );
      await _storage.save(session);
      _session = session;
      _status = AuthStatus.authenticated;
    });
  }

  /// Atualiza nome e (opcionalmente) senha do usuário logado.
  Future<bool> updateProfile({required String name, String? password}) {
    return _run(() async {
      final token = _session?.token;
      if (token == null) throw const ApiException('Sessão expirada.');
      final user = await _authService.updateMe(
        token,
        name: name,
        password: password,
      );
      _session = _session!.copyWith(user: user);
      await _storage.saveUser(user);
    });
  }

  /// Atualiza avatar do usuário logado.
  Future<bool> updateAvatar(XFile file) {
    return _run(() async {
      final token = _session?.token;
      if (token == null) throw const ApiException('Sessão expirada.');
      final user = await _authService.updateAvatar(token, file);
      _session = _session!.copyWith(user: user);
      await _storage.saveUser(user);
    });
  }

  /// Encerra a sessão e volta ao login.
  Future<void> logout() async {
    await _storage.clear();
    _session = null;
    _error = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Chamado pelo `AuthHttpClient` quando uma chamada autenticada recebe `401`.
  void onUnauthorized() {
    if (_status == AuthStatus.authenticated) {
      logout();
    }
  }

  /// Limpa a mensagem de erro (ao reabrir um formulário, por ex.).
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Executa uma ação de rede gerenciando `busy`/`error` e notificação.
  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      _busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _busy = false;
      _error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _busy = false;
      _error = 'Algo deu errado. Tente novamente.';
      notifyListeners();
      return false;
    }
  }
}
