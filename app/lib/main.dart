import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/fish_service.dart';

void main() {
  runApp(const FishingApp());
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
  /// Serviço opcional injetado nos testes; em produção fica nulo e cada
  /// tela cria a sua própria instância.
  final FishService? fishService;

  const FishingApp({super.key, this.fishService});

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
      home: HomeShell(fishService: fishService),
    );
  }
}