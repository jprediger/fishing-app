import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'config/app_log.dart';
import 'screens/auth_gate.dart';
import 'screens/home_shell.dart';
import 'services/auth_http_client.dart';
import 'services/catch_service.dart';
import 'services/establishment_service.dart';
import 'services/fish_service.dart';
import 'services/profile_service.dart';
import 'services/water_body_service.dart';
import 'state/auth_controller.dart';
import 'theme/app_theme.dart';

// Re-exporta os tokens de marca para que `import '../main.dart'` continue
// dando acesso a `AppColors` durante a migração das telas para o `colorScheme`.
// Ver docs/plans/todo: migração de hardcodes de cor.
export 'theme/app_colors.dart';

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
  final catchService = CatchService(client: httpClient);
  final profileService = ProfileService(client: httpClient);
  final waterBodyService = WaterBodyService(client: httpClient);
  final establishmentService = EstablishmentService(client: httpClient);

  // Lê a sessão salva e define o estado inicial (splash -> login/app).
  auth.bootstrap();

  runApp(
    FishingApp(
      auth: auth,
      fishService: fishService,
      catchService: catchService,
      profileService: profileService,
      waterBodyService: waterBodyService,
      establishmentService: establishmentService,
    ),
  );
}

class FishingApp extends StatelessWidget {
  /// Serviço de catálogo, injetado nos testes e no `main`.
  final FishService? fishService;

  /// Serviço de catches, injetado nos testes e no `main`.
  final CatchService? catchService;

  /// Serviço de perfil, injetado nos testes e no `main`.
  final ProfileService? profileService;

  /// Serviço do mapa, injetado nos testes e no `main`.
  final WaterBodyService? waterBodyService;

  /// Serviço de estabelecimentos, injetado nos testes e no `main`.
  final EstablishmentService? establishmentService;

  /// Sessão do app. Quando presente, o `AuthGate` decide login ↔ app.
  final AuthController? auth;

  const FishingApp({
    super.key,
    this.fishService,
    this.catchService,
    this.profileService,
    this.waterBodyService,
    this.establishmentService,
    this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pescaria',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: auth != null
          ? AuthGate(
              auth: auth!,
              fishService: fishService ?? FishService(),
              catchService: catchService ?? CatchService(),
              profileService: profileService ?? ProfileService(),
              waterBodyService: waterBodyService ?? WaterBodyService(),
              establishmentService:
                  establishmentService ?? EstablishmentService(),
            )
          : HomeShell(
              fishService: fishService,
              catchService: catchService,
              profileService: profileService,
              waterBodyService: waterBodyService,
              establishmentService: establishmentService,
            ),
    );
  }
}
