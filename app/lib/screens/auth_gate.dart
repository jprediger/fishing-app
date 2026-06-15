import 'package:flutter/material.dart';

import '../main.dart';
import '../services/catch_service.dart';
import '../services/fish_service.dart';
import '../services/water_body_service.dart';
import '../state/auth_controller.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Decide, conforme o [AuthController], qual tela mostrar no topo do app:
/// splash enquanto lê o storage, login quando deslogado, app quando logado.
class AuthGate extends StatelessWidget {
  final AuthController auth;
  final FishService fishService;
  final CatchService catchService;
  final WaterBodyService waterBodyService;

  const AuthGate({
    super.key,
    required this.auth,
    required this.fishService,
    required this.catchService,
    required this.waterBodyService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const _SplashScreen();
          case AuthStatus.unauthenticated:
            return LoginScreen(auth: auth);
          case AuthStatus.authenticated:
            return HomeShell(
              auth: auth,
              fishService: fishService,
              catchService: catchService,
              waterBodyService: waterBodyService,
            );
        }
      },
    );
  }
}

/// Tela de carregamento exibida enquanto a sessão salva é lida.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    // Brancos intencionais sobre gradiente de marca.
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.waterGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.set_meal, size: 72, color: Colors.white),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
