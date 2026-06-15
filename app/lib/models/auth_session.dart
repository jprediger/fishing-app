import 'auth_user.dart';

/// Sessão autenticada: token Bearer + usuário, retornados em `/auth/login`.
class AuthSession {
  final String token;

  /// Validade do token em segundos (informativa; sem refresh).
  final int expiresIn;
  final AuthUser user;

  const AuthSession({
    required this.token,
    required this.expiresIn,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Copia a sessão trocando apenas o usuário (após editar o perfil).
  AuthSession copyWith({AuthUser? user}) =>
      AuthSession(token: token, expiresIn: expiresIn, user: user ?? this.user);
}
