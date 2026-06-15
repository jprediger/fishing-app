import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'config/app_log.dart';
import 'screens/auth_gate.dart';
import 'screens/home_shell.dart';
import 'services/auth_http_client.dart';
import 'services/fish_service.dart';
import 'services/water_body_service.dart';
import 'state/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Erros do framework e erros assíncronos não capturados passam a sair em
  // formato único e enxuto (ver AppLog), em vez de dumps crus no console.
  FlutterError.onError = AppLog.flutterError;
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.zoneError(error, stack);
    return true;
  };

  final auth = AuthController();
  AppLog.info('API base URL: ${ApiConfig.baseUrl}');

  // Cliente HTTP autenticado: injeta o Bearer e desloga em 401.
  final httpClient = AuthHttpClient(
    tokenProvider: () => auth.token,
    onUnauthorized: auth.onUnauthorized,
  );
  final fishService = FishService(client: httpClient);
  final waterBodyService = WaterBodyService(client: httpClient);

  // Lê a sessão salva e define o estado inicial (splash -> login/app).
  auth.bootstrap();

  runApp(
    FishingApp(
      auth: auth,
      fishService: fishService,
      waterBodyService: waterBodyService,
    ),
  );
}

/// Cores base do app, inspiradas em água e natureza.
class AppColors {
  static const Color primary = Color(0xFF0B6E99); // azul água
  static const Color secondary = Color(0xFF14A38B); // verde-água
  static const Color deep = Color(0xFF073B4C); // azul profundo
  static const Color surface = Color(0xFFF3F6F8); // fundo claro
  static const Color sand = Color(0xFFF2C14E); // detalhe areia/sol

  /// Gradiente usado em cabeçalhos e destaques.
  static const LinearGradient waterGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );
}

class FishingApp extends StatelessWidget {
  /// Serviço de catálogo, injetado nos testes e no `main`.
  final FishService? fishService;

  /// Serviço do mapa, injetado nos testes e no `main`.
  final WaterBodyService? waterBodyService;

  /// Sessão do app. Quando presente, o `AuthGate` decide login ↔ app.
  final AuthController? auth;

  const FishingApp({
    super.key,
    this.fishService,
    this.waterBodyService,
    this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
    );

    return MaterialApp(
      title: 'Pescaria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.secondary.withValues(alpha: 0.18),
          elevation: 3,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.deep : Colors.black54,
            );
          }),
        ),
        chipTheme: const ChipThemeData(showCheckmark: false),
      ),
      home: auth != null
          ? AuthGate(
              auth: auth!,
              fishService: fishService ?? FishService(),
              waterBodyService: waterBodyService ?? WaterBodyService(),
            )
          : HomeShell(
              fishService: fishService,
              waterBodyService: waterBodyService,
            ),
    );
  }
}
