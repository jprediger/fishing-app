import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/auth_session.dart';
import 'package:mobile_app/models/auth_user.dart';
import 'package:mobile_app/services/token_storage.dart';

/// Fake em memória do armazenamento chave-valor.
class FakeStore implements KeyValueStore {
  final Map<String, String> map = {};

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);
}

const _session = AuthSession(
  token: 'abc123',
  expiresIn: 604800,
  user: AuthUser(
    id: 7,
    name: 'João',
    email: 'joao@test.local',
    role: UserRole.admin,
  ),
);

void main() {
  group('TokenStorage', () {
    test('salva e relê a sessão completa', () async {
      final storage = TokenStorage(store: FakeStore());
      await storage.save(_session);

      final read = await storage.read();
      expect(read, isNotNull);
      expect(read!.token, 'abc123');
      expect(read.expiresIn, 604800);
      expect(read.user.name, 'João');
      expect(read.user.role, UserRole.admin);
    });

    test('retorna null quando não há sessão salva', () async {
      final storage = TokenStorage(store: FakeStore());
      expect(await storage.read(), isNull);
    });

    test('saveUser atualiza só o usuário, mantendo o token', () async {
      final store = FakeStore();
      final storage = TokenStorage(store: store);
      await storage.save(_session);

      await storage.saveUser(
        const AuthUser(
          id: 7,
          name: 'João Editado',
          email: 'joao@test.local',
          role: UserRole.user,
        ),
      );

      final read = await storage.read();
      expect(read!.token, 'abc123');
      expect(read.user.name, 'João Editado');
      expect(read.user.role, UserRole.user);
    });

    test('clear apaga toda a sessão', () async {
      final storage = TokenStorage(store: FakeStore());
      await storage.save(_session);
      await storage.clear();
      expect(await storage.read(), isNull);
    });
  });
}
