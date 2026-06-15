import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuração de acesso ao backend Spring Boot.
///
/// O endereço base muda conforme a plataforma de execução:
/// - No emulador Android, `localhost` da máquina é acessível via `10.0.2.2`.
/// - Em web/desktop/iOS simulador, `localhost` funciona normalmente.
///
/// Pode ser sobrescrito em tempo de compilação com:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8081`
class ApiConfig {
  const ApiConfig._();

  static const String _override = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8081';
    }
    return 'http://localhost:8081';
  }
}
