import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tipos de marcador exibidos no mapa. Cada tipo carrega sua própria cor
/// semântica e glifo — adicionar um novo tipo é só acrescentar um caso aqui.
enum MapMarkerKind {
  waterBody(AppColors.markerWaterBody, Icons.water_drop),
  catchRecordMine(AppColors.markerCatchMine, Icons.set_meal),
  catchRecord(AppColors.markerCatchOther, Icons.set_meal),
  establishment(AppColors.markerEstablishment, Icons.store);

  const MapMarkerKind(this.color, this.icon);

  final Color color;
  final IconData icon;
}

/// Marcador padronizado do mapa: um círculo cheio com borda branca, sombra
/// suave e um glifo branco ao centro. Ancorado pelo centro na coordenada.
///
/// Quando [selected], cresce e ganha um halo translúcido na cor do tipo. Todos
/// os tipos compartilham forma e tamanho — a identidade vem de cor + glifo.
class MapMarker extends StatelessWidget {
  final MapMarkerKind kind;
  final bool selected;
  final int? badgeCount;

  const MapMarker({
    super.key,
    required this.kind,
    this.selected = false,
    this.badgeCount,
  });

  /// Diâmetro padrão do círculo.
  static const double size = 40;

  /// Diâmetro quando selecionado.
  static const double selectedSize = 52;

  /// Espessura da borda branca.
  static const double borderWidth = 2.5;

  /// Folga ao redor do círculo para acomodar o halo de seleção. Define o
  /// tamanho fixo do [Marker] no mapa, mantendo a área de toque estável.
  static const double _haloPadding = 8;

  /// Footprint fixo do marcador (use como width/height do [Marker]).
  static const double footprint = selectedSize + _haloPadding * 2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diameter = selected ? selectedSize : size;

    return SizedBox(
      width: footprint,
      height: footprint,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: selected ? diameter + _haloPadding * 2 : diameter,
          height: selected ? diameter + _haloPadding * 2 : diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? kind.color.withValues(alpha: 0.22)
                : Colors.transparent,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kind.color,
                    border: Border.all(color: Colors.white, width: borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(
                          alpha: selected ? 0.4 : 0.3,
                        ),
                        blurRadius: selected ? 10 : 6,
                        offset: Offset(0, selected ? 4 : 2),
                      ),
                    ],
                  ),
                  // Branco intencional do glifo sobre o círculo colorido.
                  child: Icon(
                    kind.icon,
                    color: Colors.white,
                    size: diameter * 0.5,
                  ),
                ),
              ),
              if (badgeCount != null && badgeCount! > 0)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deep,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
