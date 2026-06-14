import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../models/water_body.dart';
import '../services/api_exception.dart';
import '../services/water_body_service.dart';

class MapScreen extends StatefulWidget {
  final WaterBodyService? service;

  const MapScreen({super.key, this.service});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _initialCenter = LatLng(-30.0846, -51.2645);

  final MapController _mapController = MapController();
  Timer? _viewportDebounce;
  int _selectedIndex = 0;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  late final WaterBodyService _service;
  List<WaterBody> _waterBodies = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? WaterBodyService();
    _loadWaterBodies();
  }

  @override
  void dispose() {
    _viewportDebounce?.cancel();
    if (widget.service == null) {
      _service.dispose();
    }
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadWaterBodies({String? bbox}) async {
    final loadingInitial = _waterBodies.isEmpty;
    setState(() {
      if (loadingInitial) {
        _loading = true;
      } else {
        _refreshing = true;
      }
      _error = null;
    });

    try {
      final waterBodies = await _service.fetchWaterBodies(bbox: bbox);
      if (!mounted) return;
      setState(() {
        _waterBodies = waterBodies;
        if (_selectedIndex >= waterBodies.length) {
          _selectedIndex = 0;
        }
        _loading = false;
        _refreshing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _scheduleViewportLoad(MapCamera camera) {
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 350), () {
      final bounds = camera.visibleBounds;
      final bbox = '${bounds.west},${bounds.south},${bounds.east},${bounds.north}';
      unawaited(_loadWaterBodies(bbox: bbox));
    });
  }

  void _selectBody(int index) {
    if (_waterBodies.isEmpty) return;
    final safeIndex = index.clamp(0, _waterBodies.length - 1);
    final body = _waterBodies[safeIndex];
    final location = body.centerLocation ?? _fallbackCenter(body);

    setState(() => _selectedIndex = safeIndex);
    _mapController.move(location, 11.5);
  }

  LatLng _fallbackCenter(WaterBody body) {
    final geometry = body.geometry;
    final coordinates = geometry['coordinates'];

    if (coordinates is List && coordinates.isNotEmpty) {
      final first = _firstLatLng(coordinates);
      if (first != null) return first;
    }

    return _initialCenter;
  }

  LatLng? _firstLatLng(dynamic coordinates) {
    if (coordinates is List && coordinates.isNotEmpty) {
      final first = coordinates.first;
      if (first is List && first.length >= 2 && first[0] is num && first[1] is num) {
        return LatLng((first[1] as num).toDouble(), (first[0] as num).toDouble());
      }
      if (first is List) {
        return _firstLatLng(first);
      }
    }
    return null;
  }

  void _showDetails(WaterBody body) {
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
                const Icon(Icons.water_drop, color: AppColors.primary, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    body.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${body.waterType.label} • ${body.source ?? "OSM"}'
              '${body.osmId == null ? "" : " • OSM ${body.osmId}"}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Geometria ${body.geometryType ?? "desconhecida"}',
              style: const TextStyle(height: 1.4, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Centralizar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 10.7,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _scheduleViewportLoad(camera);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobile_app',
              ),
              if (_lineStrings.isNotEmpty)
                PolylineLayer<Object>(polylines: _lineStrings),
              if (_polygons.isNotEmpty)
                PolygonLayer<Object>(polygons: _polygons),
              MarkerLayer(markers: _markers),
            ],
          ),
          _buildHeaderPill(),
          if (_waterBodies.isNotEmpty) _buildCarousel(),
          if (_refreshing) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
          if (_error != null) _buildErrorBanner(),
          if (_waterBodies.isEmpty && _error == null) _buildEmptyState(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 150),
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 3,
          onPressed: () => _mapController.move(_initialCenter, 10.7),
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
                  child: const Icon(Icons.water, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Corpos d\'água',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                    '${_waterBodies.length}',
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

  Widget _buildCarousel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 132,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: _waterBodies.length,
          itemBuilder: (context, index) {
            final body = _waterBodies[index];
            final selected = index == _selectedIndex;
            return GestureDetector(
              onTap: () => _selectBody(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 260,
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
                        const Icon(Icons.water_drop,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            body.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body.waterType.label,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        'Geometria ${body.geometryType ?? "desconhecida"}'
                        '${body.osmId == null ? "" : " • OSM ${body.osmId}"}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.3,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showDetails(body),
                      child: const Row(
                        children: [
                          Text(
                            'Ver detalhes',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
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

  Widget _buildErrorBanner() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 70),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Nenhum corpo d\'água nesta área.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Polyline<Object>> get _lineStrings {
    final lines = <Polyline<Object>>[];
    for (final body in _waterBodies) {
      lines.addAll(_linesForBody(body));
    }
    return lines;
  }

  List<Polygon<Object>> get _polygons {
    final polygons = <Polygon<Object>>[];
    for (final body in _waterBodies) {
      polygons.addAll(_polygonsForBody(body));
    }
    return polygons;
  }

  List<Marker> get _markers {
    return [
      for (var i = 0; i < _waterBodies.length; i++)
        Marker(
          point: _waterBodies[i].centerLocation ?? _fallbackCenter(_waterBodies[i]),
          width: 46,
          height: 46,
          child: GestureDetector(
            onTap: () => _selectBody(i),
            child: _MapPin(selected: i == _selectedIndex),
          ),
        ),
    ];
  }

  List<Polyline<Object>> _linesForBody(WaterBody body) {
    final geometry = body.geometry;
    final type = geometry['type'] as String?;
    if (type == 'LineString') {
      final points = _latLngList(geometry['coordinates']);
      if (points.length >= 2) {
        return [
          Polyline<Object>(
            points: points,
            strokeWidth: 4,
            color: AppColors.primary.withValues(alpha: 0.75),
          ),
        ];
      }
    }

    if (type == 'MultiLineString') {
      final coordinates = geometry['coordinates'];
      if (coordinates is List) {
        return coordinates
            .whereType<List>()
            .map(_latLngList)
            .where((points) => points.length >= 2)
            .map(
              (points) => Polyline<Object>(
                points: points,
                strokeWidth: 4,
                color: AppColors.primary.withValues(alpha: 0.75),
              ),
            )
            .toList();
      }
    }

    return const [];
  }

  List<Polygon<Object>> _polygonsForBody(WaterBody body) {
    final geometry = body.geometry;
    final type = geometry['type'] as String?;
    if (type == 'Polygon') {
      return [_polygonFromCoordinates(geometry['coordinates'])];
    }

    if (type == 'MultiPolygon') {
      final coordinates = geometry['coordinates'];
      if (coordinates is List) {
        return coordinates
            .whereType<List>()
            .map((polygon) => _polygonFromCoordinates(polygon))
            .toList();
      }
    }

    return const [];
  }

  Polygon<Object> _polygonFromCoordinates(dynamic coordinates) {
    final rings = coordinates is List ? coordinates : const [];
    final outer = rings.isNotEmpty ? _latLngList(rings.first) : const <LatLng>[];
    final holes = rings.length > 1
        ? rings.skip(1).map(_latLngList).where((ring) => ring.isNotEmpty).toList()
        : <List<LatLng>>[];

    return Polygon<Object>(
      points: outer,
      holePointsList: holes.isEmpty ? null : holes,
      color: AppColors.secondary.withValues(alpha: 0.18),
      borderColor: AppColors.secondary.withValues(alpha: 0.85),
      borderStrokeWidth: 2,
    );
  }

  List<LatLng> _latLngList(dynamic coordinates) {
    if (coordinates is! List) return const [];

    return coordinates
        .whereType<List>()
        .where((pair) => pair.length >= 2 && pair[0] is num && pair[1] is num)
        .map(
          (pair) => LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          ),
        )
        .toList();
  }
}

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
