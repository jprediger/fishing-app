/// Erro lançado quando uma chamada ao backend falha. Carrega uma mensagem
/// amigável e, quando disponível, o código HTTP que a originou.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  /// Verdadeiro quando a falha foi por token ausente/inválido (`401`).
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
