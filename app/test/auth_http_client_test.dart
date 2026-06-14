import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/services/auth_http_client.dart';

void main() {
  group('AuthHttpClient', () {
    test('injeta Authorization: Bearer quando há token', () async {
      String? seen;
      final client = AuthHttpClient(
        tokenProvider: () => 'tok-1',
        onUnauthorized: () {},
        inner: MockClient((req) async {
          seen = req.headers['Authorization'];
          return http.Response('ok', 200);
        }),
      );

      await client.get(Uri.parse('http://test.local/api/fish'));
      expect(seen, 'Bearer tok-1');
    });

    test('não injeta header quando token é nulo', () async {
      String? seen = 'unset';
      final client = AuthHttpClient(
        tokenProvider: () => null,
        onUnauthorized: () {},
        inner: MockClient((req) async {
          seen = req.headers['Authorization'];
          return http.Response('ok', 200);
        }),
      );

      await client.get(Uri.parse('http://test.local/api/fish'));
      expect(seen, isNull);
    });

    test('dispara onUnauthorized em 401', () async {
      var called = false;
      final client = AuthHttpClient(
        tokenProvider: () => 'tok-1',
        onUnauthorized: () => called = true,
        inner: MockClient((_) async => http.Response('no', 401)),
      );

      await client.get(Uri.parse('http://test.local/api/fish'));
      expect(called, isTrue);
    });
  });
}
