import 'package:mobile_app/services/token_storage.dart';

/// Fake em memória do armazenamento chave-valor, compartilhado pelos testes.
class FakeStore implements KeyValueStore {
  final Map<String, String> map = {};

  @override
  Future<String?> read(String key) async => map[key];

  @override
  Future<void> write(String key, String value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);
}
