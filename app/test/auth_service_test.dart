import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/models/auth_user.dart';
import 'package:mobile_app/services/api_exception.dart';
import 'package:mobile_app/services/auth_service.dart';

const _base = 'http://test.local';

AuthService _service(MockClient client) =>
    AuthService(client: client, baseUrl: _base);

const _loginBody = {
  'token': 'jwt-123',
  'tokenType': 'Bearer',
  'expiresIn': 604800,
  'user': {
    'id': 1,
    'name': 'Admin',
    'email': 'admin@fishing.local',
    'role': 'ADMIN',
  },
};

void main() {
  group('AuthService.register', () {
    test('envia name/email/password e aceita 201', () async {
      late Map<String, dynamic> sent;
      final service = _service(MockClient((req) async {
        expect(req.url.path, '/auth/register');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('', 201);
      }));

      await service.register(
          name: 'Ana', email: 'ana@test.local', password: 'segredo123');
      expect(sent['name'], 'Ana');
      expect(sent['email'], 'ana@test.local');
      expect(sent['password'], 'segredo123');
    });

    test('mapeia 409 para mensagem de e-mail duplicado', () async {
      final service =
          _service(MockClient((_) async => http.Response('', 409)));
      await expectLater(
        service.register(name: 'A', email: 'a@a.com', password: '12345678'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('mapeia 400 para dados inválidos', () async {
      final service =
          _service(MockClient((_) async => http.Response('', 400)));
      await expectLater(
        service.register(name: 'A', email: 'a@a.com', password: '12345678'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('AuthService.login', () {
    test('faz parse da sessão em 200', () async {
      final service = _service(MockClient((req) async {
        expect(req.url.path, '/auth/login');
        return http.Response(jsonEncode(_loginBody), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));

      final session =
          await service.login(email: 'admin@fishing.local', password: 'x');
      expect(session.token, 'jwt-123');
      expect(session.expiresIn, 604800);
      expect(session.user.role, UserRole.admin);
    });

    test('mapeia 401 para credenciais inválidas', () async {
      final service =
          _service(MockClient((_) async => http.Response('', 401)));
      await expectLater(
        service.login(email: 'a@a.com', password: 'wrong'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('mapeia falha de conexão para ApiException', () async {
      final service =
          _service(MockClient((_) async => throw Exception('offline')));
      await expectLater(
        service.login(email: 'a@a.com', password: 'x'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('AuthService.me / updateMe', () {
    test('me envia Bearer e retorna o usuário', () async {
      late String authHeader;
      final service = _service(MockClient((req) async {
        expect(req.url.path, '/api/users/me');
        authHeader = req.headers['Authorization'] ?? '';
        return http.Response(jsonEncode(_loginBody['user']), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));

      final user = await service.me('jwt-123');
      expect(authHeader, 'Bearer jwt-123');
      expect(user.email, 'admin@fishing.local');
    });

    test('updateMe envia name e password quando informados', () async {
      late Map<String, dynamic> sent;
      final service = _service(MockClient((req) async {
        expect(req.method, 'PUT');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        final updated = Map<String, dynamic>.from(
            _loginBody['user'] as Map<String, dynamic>)
          ..['name'] = sent['name'];
        return http.Response(jsonEncode(updated), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));

      final user = await service.updateMe('jwt-123',
          name: 'Novo Nome', password: 'novaSenha123');
      expect(sent['name'], 'Novo Nome');
      expect(sent['password'], 'novaSenha123');
      expect(user.name, 'Novo Nome');
    });

    test('updateMe omite password quando vazio', () async {
      late Map<String, dynamic> sent;
      final service = _service(MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_loginBody['user']), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));

      await service.updateMe('jwt-123', name: 'Só Nome', password: '');
      expect(sent.containsKey('password'), isFalse);
    });

    test('me mapeia 401 para sessão expirada', () async {
      final service =
          _service(MockClient((_) async => http.Response('', 401)));
      await expectLater(
        service.me('jwt-123'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });
}
