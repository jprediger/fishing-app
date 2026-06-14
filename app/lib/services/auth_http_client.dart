import 'package:http/http.dart' as http;

/// [http.Client] que injeta o cabeçalho `Authorization: Bearer <token>` em
/// toda requisição e, ao receber `401`, dispara um callback de logout.
///
/// O token é resolvido de forma preguiçosa via [tokenProvider], então sempre
/// usa o valor atual da sessão (ou `null` quando deslogado).
class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;
  final String? Function() tokenProvider;
  final void Function() onUnauthorized;

  AuthHttpClient({
    required this.tokenProvider,
    required this.onUnauthorized,
    http.Client? inner,
  }) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = tokenProvider();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      onUnauthorized();
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
