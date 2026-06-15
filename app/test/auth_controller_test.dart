import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/models/auth_session.dart';
import 'package:mobile_app/models/auth_user.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/token_storage.dart';
import 'package:mobile_app/state/auth_controller.dart';

import 'support/fake_store.dart';

const _loginBody = {
  'token': 'jwt-123',
  'tokenType': 'Bearer',
  'expiresIn': 604800,
  'user': {
    'id': 2,
    'name': 'Demo',
    'email': 'demo@fishing.local',
    'role': 'USER',
  },
};

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

AuthController _controller(MockClient client, TokenStorage storage) =>
    AuthController(
      authService: AuthService(client: client, baseUrl: 'http://test.local'),
      storage: storage,
    );

void main() {
  group('bootstrap', () {
    test('sem sessão salva -> unauthenticated', () async {
      final auth = _controller(
        MockClient((_) async => http.Response('', 404)),
        TokenStorage(store: FakeStore()),
      );
      await auth.bootstrap();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.user, isNull);
    });

    test('com sessão salva -> authenticated', () async {
      final storage = TokenStorage(store: FakeStore());
      await storage.save(
        const AuthSession(
          token: 'saved',
          expiresIn: 10,
          user: AuthUser(
            id: 1,
            name: 'A',
            email: 'a@a.com',
            role: UserRole.user,
          ),
        ),
      );

      final auth = _controller(
        MockClient((_) async => http.Response('', 404)),
        storage,
      );
      await auth.bootstrap();
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.token, 'saved');
    });
  });

  group('login', () {
    test('sucesso -> authenticated + persiste token', () async {
      final store = FakeStore();
      final auth = _controller(
        MockClient((_) async => _ok(_loginBody)),
        TokenStorage(store: store),
      );

      final ok = await auth.login('demo@fishing.local', 'demo12345');
      expect(ok, isTrue);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.token, 'jwt-123');
      expect(auth.error, isNull);
      // Persistiu no storage.
      expect(store.map['auth_token'], 'jwt-123');
    });

    test('401 -> continua unauthenticated com mensagem de erro', () async {
      final auth = _controller(
        MockClient((_) async => http.Response('', 401)),
        TokenStorage(store: FakeStore()),
      );
      await auth.bootstrap();

      final ok = await auth.login('x@x.com', 'wrong');
      expect(ok, isFalse);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.error, isNotNull);
    });
  });

  group('register', () {
    test('sucesso faz auto-login -> authenticated', () async {
      final auth = _controller(
        MockClient((req) async {
          if (req.url.path == '/auth/register') return http.Response('', 201);
          return _ok(_loginBody);
        }),
        TokenStorage(store: FakeStore()),
      );

      final ok = await auth.register('Demo', 'demo@fishing.local', 'demo12345');
      expect(ok, isTrue);
      expect(auth.status, AuthStatus.authenticated);
    });
  });

  group('logout / onUnauthorized', () {
    test('logout limpa sessão e storage', () async {
      final store = FakeStore();
      final auth = _controller(
        MockClient((_) async => _ok(_loginBody)),
        TokenStorage(store: store),
      );
      await auth.login('demo@fishing.local', 'demo12345');

      await auth.logout();
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.token, isNull);
      expect(store.map['auth_token'], isNull);
    });

    test('onUnauthorized desloga quando autenticado', () async {
      final auth = _controller(
        MockClient((_) async => _ok(_loginBody)),
        TokenStorage(store: FakeStore()),
      );
      await auth.login('demo@fishing.local', 'demo12345');
      expect(auth.status, AuthStatus.authenticated);

      auth.onUnauthorized();
      // logout é assíncrono; aguarda o microtask.
      await Future<void>.delayed(Duration.zero);
      expect(auth.status, AuthStatus.unauthenticated);
    });
  });
}
