/// Papel do usuário, espelha o enum `Role` do backend.
enum UserRole {
  user('USER', 'Usuário'),
  admin('ADMIN', 'Administrador');

  final String apiValue;
  final String label;

  const UserRole(this.apiValue, this.label);

  static UserRole fromApi(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.apiValue == value,
      orElse: () => UserRole.user,
    );
  }
}

/// Usuário autenticado, retornado em `/auth/login` e `/api/users/me`.
class AuthUser {
  final int id;
  final String name;
  final String email;
  final UserRole role;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromApi(json['role'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.apiValue,
  };
}
