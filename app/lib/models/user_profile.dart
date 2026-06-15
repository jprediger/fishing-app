import 'auth_user.dart';

class UserProfile {
  final int id;
  final String name;
  final String? avatarPath;
  final UserRole role;
  final DateTime? memberSince;
  final int catchCount;
  final int speciesCount;
  final int waterBodyCount;

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarPath,
    required this.role,
    required this.memberSince,
    required this.catchCount,
    required this.speciesCount,
    required this.waterBodyCount,
  });

  bool get isAdmin => role == UserRole.admin;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      avatarPath: json['avatarPath'] as String?,
      role: UserRole.fromApi(json['role'] as String?),
      memberSince: DateTime.tryParse(json['memberSince'] as String? ?? ''),
      catchCount: (json['catchCount'] as num?)?.toInt() ?? 0,
      speciesCount: (json['speciesCount'] as num?)?.toInt() ?? 0,
      waterBodyCount: (json['waterBodyCount'] as num?)?.toInt() ?? 0,
    );
  }
}
