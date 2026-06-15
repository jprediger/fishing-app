import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Temas claro e escuro do app, derivados da mesma identidade de marca
/// ([AppColors]) para garantir um design coerente entre os dois modos.
///
/// Ambos os temas são construídos a partir de um único [ColorScheme] gerado
/// pela seed da marca. Os component themes referenciam **tokens do
/// colorScheme** (não cores fixas), de modo que claro e escuro saem coerentes
/// e as telas só precisam ler de `Theme.of(context).colorScheme`.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      // Fundo um nível abaixo das superfícies/cards, criando profundidade em
      // ambos os temas.
      scaffoldBackgroundColor: colorScheme.surfaceContainerLow,
      // AppBar transparente: as telas desenham o gradiente de água por baixo,
      // sobre o qual o branco funciona em claro e escuro.
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
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: const ChipThemeData(showCheckmark: false),
    );
  }
}
