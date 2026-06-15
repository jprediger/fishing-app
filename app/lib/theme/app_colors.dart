import 'package:flutter/material.dart';

/// Tokens de marca do app (identidade visual), inspirados em água e natureza.
///
/// Estas são as cores de **identidade** — independentes de claro/escuro. As
/// cores derivadas (fundos, superfícies, textos) vêm do [ColorScheme] do tema
/// (ver `app_theme.dart`); use `Theme.of(context).colorScheme` nas telas em vez
/// de cores fixas, para que respondam ao tema claro/escuro.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0B6E99); // azul água
  static const Color secondary = Color(0xFF14A38B); // verde-água
  static const Color deep = Color(0xFF073B4C); // azul profundo
  static const Color sand = Color(0xFFF2C14E); // detalhe areia/sol

  // Cores semânticas dos marcadores do mapa: nomeadas pelo papel (não pela
  // marca crua) para que a paleta de marcadores evolua num só lugar. Usadas
  // pelo design system de marcadores (ver `widgets/map_marker.dart`).
  static const Color markerWaterBody = secondary; // corpos d'água
  static const Color markerCatchMine = deep; // pesca própria
  static const Color markerCatchOther = Color(0xFF2EC4B6); // pesca de outros
  static const Color markerCatch = markerCatchOther; // alias legado
  static const Color markerEstablishment = sand; // estabelecimentos (futuro)
  static const Color markerUser = Color(0xFF355CDE); // posição do usuário

  /// Fundo claro legado. Mantido por compatibilidade; prefira
  /// `colorScheme.surface` para responder ao tema.
  static const Color surface = Color(0xFFF3F6F8);

  /// Gradiente usado em cabeçalhos e destaques. Funciona em ambos os temas
  /// porque carrega a identidade da marca (água) com texto branco por cima.
  static const LinearGradient waterGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );
}
