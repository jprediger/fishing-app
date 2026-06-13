import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';

/// Modelo simples de um ponto de pesca exibido no mapa.
class FishingSpot {
  final String name;
  final LatLng location;
  final String description;

  const FishingSpot({
    required this.name,
    required this.location,
    required this.description,
  });
}

/// Tela do mapa com os pontos de pesca cadastrados.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  int _selectedIndex = 0;

  // Pontos de exemplo (área de Porto Alegre / Lagoa dos Patos).
  static const List<FishingSpot> _spots = [
    FishingSpot(
      name: 'Lago Guaíba',
      location: LatLng(-30.0846, -51.2645),
      description: 'Traíras e tilápias perto da orla.',
    ),
    FishingSpot(
      name: 'Lagoa dos Patos',
      location: LatLng(-31.2000, -51.3000),
      description: 'Pesca de tainha e corvina.',
    ),
    FishingSpot(
      name: 'Delta do Jacuí',
      location: LatLng(-29.9700, -51.2200),
      description: 'Bom para dourado e jundiá.',
    ),
  ];

  static const LatLng _initialCenter = LatLng(-30.0846, -51.2645);

  void _selectSpot(int index) {
    setState(() => _selectedIndex = index);
    _mapController.move(_spots[index].location, 12);
  }

  void _showSpotDetails(FishingSpot spot) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: AppColors.primary, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spot.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(spot.description,
                style: const TextStyle(height: 1.4, color: Colors.black87)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.directions),
                label: const Text('Ver rota'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 11,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobile_app',
              ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < _spots.length; i++)
                    Marker(
                      point: _spots[i].location,
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () => _selectSpot(i),
                        child: _MapPin(selected: i == _selectedIndex),
                      ),
                    ),
                ],
              ),
            ],
          ),
          _buildHeaderPill(),
          _buildSpotCarousel(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 150),
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 3,
          onPressed: () => _mapController.move(_initialCenter, 11),
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }

  Widget _buildHeaderPill() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppColors.waterGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.set_meal,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Pontos de pesca',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_spots.length}',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotCarousel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 130,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: _spots.length,
          itemBuilder: (context, index) {
            final spot = _spots[index];
            final selected = index == _selectedIndex;
            return GestureDetector(
              onTap: () => _selectSpot(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 250,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spot.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        spot.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54, height: 1.3),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showSpotDetails(spot),
                      child: const Row(
                        children: [
                          Text('Ver detalhes',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          Icon(Icons.chevron_right,
                              color: AppColors.primary, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Marcador customizado em forma de gota.
class _MapPin extends StatelessWidget {
  final bool selected;
  const _MapPin({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_on,
      color: selected ? AppColors.primary : AppColors.deep,
      size: selected ? 46 : 38,
      shadows: const [
        Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
      ],
    );
  }
}
