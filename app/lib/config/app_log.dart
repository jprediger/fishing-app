import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

/// Logging centralizado do app.
///
/// Usa `dart:developer` (níveis + `name`), então a saída fica filtrável na IDE
/// (DevTools / console) e é descartada em builds de release. Substitui `print`
/// — coerente com o lint `avoid_print`.
///
/// Falhas de tile do mapa são agregadas (ver [tileError]) para não inundarem o
/// console quando muitos tiles falham ao mesmo tempo (ex.: rede instável).
class AppLog {
  const AppLog._();

  static const int _levelInfo = 800; // Level.INFO
  static const int _levelWarning = 900; // Level.WARNING
  static const int _levelError = 1000; // Level.SEVERE

  static void info(String message, {String name = 'app'}) {
    dev.log(message, name: name, level: _levelInfo);
  }

  static void warn(String message, {String name = 'app'}) {
    dev.log(message, name: name, level: _levelWarning);
  }

  static void error(
    String message, {
    String name = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    dev.log(
      message,
      name: name,
      level: _levelError,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Handler para `FlutterError.onError`: emite uma entrada compacta em vez do
  /// dump vermelho padrão do framework.
  static void flutterError(FlutterErrorDetails details) {
    dev.log(
      details.exceptionAsString(),
      name: 'flutter',
      level: _levelError,
      error: details.exception,
      // Stack completa só em debug; em release fica enxuto.
      stackTrace: kDebugMode ? details.stack : null,
    );
  }

  /// Handler para `PlatformDispatcher.instance.onError`: erros assíncronos não
  /// capturados fora da árvore de widgets.
  static void zoneError(Object error, StackTrace stack) {
    dev.log(
      'Erro não tratado',
      name: 'app',
      level: _levelError,
      error: error,
      stackTrace: kDebugMode ? stack : null,
    );
  }

  // --- Agregação de falhas de tile do mapa --------------------------------
  static const Duration _tileWindow = Duration(seconds: 3);
  static int _tileErrorCount = 0;
  static DateTime? _tileWindowStart;

  /// Registra uma falha de carregamento de tile sem poluir o console: acumula
  /// as ocorrências e emite, no máximo, um resumo a cada 3 segundos.
  ///
  /// Usa uma janela baseada em relógio (sem `Timer`), evitando timers pendentes
  /// que fariam widget tests falharem ao desmontar a árvore.
  static void tileError(Object error) {
    _tileErrorCount++;
    final now = DateTime.now();
    _tileWindowStart ??= now;
    if (now.difference(_tileWindowStart!) >= _tileWindow) {
      dev.log(
        '$_tileErrorCount tile(s) do mapa falharam ao carregar (último: $error)',
        name: 'map',
        level: _levelWarning,
      );
      _tileErrorCount = 0;
      _tileWindowStart = null;
    }
  }
}
