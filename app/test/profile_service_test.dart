import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/models/auth_user.dart';
import 'package:mobile_app/models/user_profile.dart';
import 'package:mobile_app/services/profile_service.dart';

void main() {
  test('faz parse do perfil público com stats reais', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/users/7');
      expect(request.headers['Authorization'], 'Bearer jwt-123');
      return http.Response(
        jsonEncode({
          'id': 7,
          'name': 'Ana',
          'avatarPath': 'avatars/ana.webp',
          'role': 'ADMIN',
          'memberSince': '2024-01-10T12:00:00Z',
          'catchCount': 12,
          'speciesCount': 5,
          'waterBodyCount': 3,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = ProfileService(
      client: client,
      baseUrl: 'http://test.local',
    );
    final profile = await service.fetchProfile('jwt-123', 7);

    expect(profile, isA<UserProfile>());
    expect(profile.id, 7);
    expect(profile.name, 'Ana');
    expect(profile.avatarPath, 'avatars/ana.webp');
    expect(profile.role, UserRole.admin);
    expect(profile.catchCount, 12);
    expect(profile.speciesCount, 5);
    expect(profile.waterBodyCount, 3);
  });
}
