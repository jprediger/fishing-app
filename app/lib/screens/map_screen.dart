import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_log.dart';
import '../main.dart';
import '../models/catch_draft.dart';
import '../models/catch_record.dart';
import '../models/water_body.dart';
import '../services/catch_service.dart';
import '../services/fish_service.dart';
import '../services/water_body_service.dart';
import '../widgets/map_marker.dart';
import 'catch_detail_screen.dart';
import 'catch_form_screen.dart';

class MapScreen extends StatefulWidget {
  final WaterBodyService? waterBodyService;
  final FishService? fishService;
  final CatchService? catchService;
  final String? authToken;

  /// Test hook: pre-seeds draft point when mark mode opens.
  final LatLng? debugInitialDraftPoint;

  const MapScreen({
    super.key,
    this.waterBodyService,
    this.fishService,
    this.catchService,
    this.authToken,
    this.debugInitialDraftPoint,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _NearestStatus { idle, loading, found, notFound, error }

class _MapScreenState extends State<MapScreen> {
  static const LatLng _initialCenter = LatLng(-30.0846, -51.2645);
  static const double _initialZoom = 10.7;
  static const double _minViewportZoom = 9.0;

  /// Acima deste zoom os pins dos corpos d'água aparecem. Abaixo, só a
  /// geometria (linhas/polígonos) fica visível para não poluir a tela.
  static const double _markerMinZoom = 12.0;

  static const double _viewportPadding = 0.2;

  final MapController _mapController = MapController();
  final CancellableNetworkTileProvider _tileProvider =
      CancellableNetworkTileProvider();
  Timer? _viewportDebounce;
  Timer? _nearestDebounce;
  Timer? _catchDebounce;
  late final WaterBodyService _service;
  late final CatchService _catchService;

  int _viewportRequestSeq = 0;
  int _nearestRequestSeq = 0;
  int _catchRequestSeq = 0;
  WaterBody? _selectedBody;
  bool _loading = true;
  bool _refreshing = false;
  bool _markingMode = false;
  double _cameraZoom = _initialZoom;
  String? _error;
  String? _nearestError;
  _Bbox? _loadedViewport;
  LatLng? _draftPoint;
  WaterBody? _nearestBody;
  _NearestStatus _nearestStatus = _NearestStatus.idle;
  List<WaterBody> _waterBodies = const [];
  List<CatchRecord> _catches = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.waterBodyService ?? WaterBodyService();
    _catchService = widget.catchService ?? CatchService();
  }

  @override
  void dispose() {
    _viewportDebounce?.cancel();
    _nearestDebounce?.cancel();
    _catchDebounce?.cancel();
    if (widget.waterBodyService == null) _service.dispose();
    if (widget.catchService == null) _catchService.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    if (!mounted) return;
    _syncCameraZoom(_mapController.camera.zoom);
    _scheduleViewportLoad(_mapController.camera, force: true);
  }

  void _syncCameraZoom(double zoom) {
    if (!mounted || (zoom - _cameraZoom).abs() < 0.01) return;
    setState(() => _cameraZoom = zoom);
  }

  void _scheduleViewportLoad(MapCamera camera, {bool force = false}) {
    _syncCameraZoom(camera.zoom);

    if (camera.zoom < _minViewportZoom) {
      _viewportDebounce?.cancel();
      _viewportRequestSeq++;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = null;
        _waterBodies = const [];
        _catches = const [];
        _selectedBody = null;
        _loadedViewport = null;
      });
      return;
    }

    final visibleBounds = camera.visibleBounds;
    if (!force && _loadedViewport?.contains(visibleBounds) == true) {
      return;
    }

    _viewportDebounce?.cancel();
    final seq = ++_viewportRequestSeq;
    final target = _Bbox.fromBounds(
      visibleBounds,
      paddingFactor: _viewportPadding,
    );
    final zoom = camera.zoom.round();

    _viewportDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadViewportData(target: target, zoom: zoom, seq: seq));
    });
  }

  Future<void> _loadViewportData({
    required _Bbox target,
    required int zoom,
    required int seq,
  }) async {
    final loadingInitial = _waterBodies.isEmpty;
    if (!mounted) return;
    setState(() {
      _loading = loadingInitial;
      _refreshing = !loadingInitial;
      _error = null;
    });

    try {
      final waterBodies = await _service.fetchWaterBodies(
        bbox: target.toQueryString(),
        zoom: zoom,
      );
      if (!mounted || seq != _viewportRequestSeq) return;
      setState(() {
        _waterBodies = waterBodies;
        if (_selectedBody != null &&
            !waterBodies.any((b) => b.id == _selectedBody!.id)) {
          _selectedBody = null;
        }
        _loading = false;
        _refreshing = false;
        _loadedViewport = target;
        if (_waterBodies.isEmpty) {
          _error = null;
        }
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _viewportRequestSeq) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _refreshing = false;
      });
      return;
    }

    if (widget.catchService != null) {
      unawaited(_loadCatches(target: target, seq: seq));
    }
  }

  Future<void> _loadCatches({required _Bbox target, required int seq}) async {
    final currentSeq = ++_catchRequestSeq;
    try {
      final catches = await _catchService.list(
        bbox: target.toQueryString(),
        page: 0,
        size: 200,
      );
      if (!mounted ||
          seq != _viewportRequestSeq ||
          currentSeq != _catchRequestSeq) {
        return;
      }
      setState(() => _catches = catches);
    } on ApiException {
      if (!mounted ||
          seq != _viewportRequestSeq ||
          currentSeq != _catchRequestSeq) {
        return;
      }
      setState(() => _catches = const []);
    }
  }

  void _toggleMarkMode() {
    if (_markingMode) {
      _exitMarkMode();
      return;
    }

    setState(() => _markingMode = true);
    _resetDraftSelection();
    if (widget.debugInitialDraftPoint != null) {
      _setDraftPoint(widget.debugInitialDraftPoint!);
    }
  }

  void _exitMarkMode() {
    setState(() => _markingMode = false);
    _resetDraftSelection();
  }

  void _resetDraftSelection() {
    _nearestDebounce?.cancel();
    _nearestRequestSeq++;
    if (!mounted) return;
    setState(() {
      _draftPoint = null;
      _nearestBody = null;
      _nearestError = null;
      _nearestStatus = _NearestStatus.idle;
    });
  }

  void _onMapTap(TapPosition _, LatLng point) {
    if (!_markingMode) {
      if (_selectedBody != null) setState(() => _selectedBody = null);
      return;
    }
    _setDraftPoint(point);
  }

  void _moveDraftByDelta(Offset delta) {
    final draftPoint = _draftPoint;
    if (draftPoint == null) return;

    final camera = _mapController.camera;
    final projected = camera.project(draftPoint);
    final movedPoint = Point<double>(
      projected.x + delta.dx,
      projected.y + delta.dy,
    );
    _setDraftPoint(camera.unproject(movedPoint));
  }

  void _setDraftPoint(LatLng point) {
    if (!mounted) return;
    setState(() {
      _draftPoint = point;
      _nearestBody = null;
      _nearestError = null;
      _nearestStatus = _NearestStatus.loading;
    });
    _scheduleNearestLookup(point);
  }

  void _scheduleNearestLookup(LatLng point) {
    _nearestDebounce?.cancel();
    final seq = ++_nearestRequestSeq;
    _nearestDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_loadNearest(point, seq));
    });
  }

  Future<void> _loadNearest(LatLng point, int seq) async {
    try {
      final waterBody = await _service.fetchNearest(
        lat: point.latitude,
        lon: point.longitude,
      );
      if (!mounted || seq != _nearestRequestSeq) return;
      setState(() {
        _nearestBody = waterBody;
        _nearestError = null;
        _nearestStatus = waterBody == null
            ? _NearestStatus.notFound
            : _NearestStatus.found;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _nearestRequestSeq) return;
      setState(() {
        _nearestBody = null;
        _nearestError = e.message;
        _nearestStatus = _NearestStatus.error;
      });
    }
  }

  void _recenter() {
    _mapController.move(_initialCenter, _initialZoom);
    _scheduleViewportLoad(_mapController.camera, force: true);
  }

  /// Seleciona o corpo d'água tocado, exibindo o card inferior. Não move
  /// nem reposiciona o mapa — apenas destaca o pin e abre o card.
  void _selectBody(WaterBody body) {
    setState(() => _selectedBody = body);
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
      if (first is List &&
          first.length >= 2 &&
          first[0] is num &&
          first[1] is num) {
        return LatLng(
          (first[1] as num).toDouble(),
          (first[0] as num).toDouble(),
        );
      }
      if (first is List) {
        return _firstLatLng(first);
      }
    }
    return null;
  }

  /// Abre o wizard de registro para o corpo d'água selecionado no mapa,
  /// usando o centro do corpo d'água como ponto inicial.
  void _openCatchFormForBody(WaterBody body) {
    final point = body.centerLocation ?? _fallbackCenter(body);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CatchFormScreen.create(
              draft: CatchDraft(point: point, waterBody: body),
              fishService: widget.fishService,
              catchService: _catchService,
            ),
          ),
        )
        .then((_) => _scheduleViewportLoad(_mapController.camera, force: true));
  }

  void _openCatchForm() {
    final point = _draftPoint;
    final waterBody = _nearestBody;
    if (point == null || waterBody == null) return;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CatchFormScreen.create(
              draft: CatchDraft(point: point, waterBody: waterBody),
              fishService: widget.fishService,
              catchService: _catchService,
            ),
          ),
        )
        .then((_) => _scheduleViewportLoad(_mapController.camera, force: true));
  }

  void _openCatchDetail(CatchRecord record) {
    final cs = Theme.of(context).colorScheme;
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
                const Icon(Icons.set_meal, color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record.species.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${record.waterBody.name} • ${_formatCatchDate(record.caughtAt)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              record.location == null ||
                      (!record.mine &&
                          record.locationVisibility ==
                              LocationVisibility.riverOnly)
                  ? 'Local aproximado'
                  : 'Ponto exato',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToCatchDetail(record);
                },
                child: const Text('Ver detalhes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCatchDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  void _navigateToCatchDetail(CatchRecord record) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CatchDetailScreen(
              initialRecord: record,
              catchService: _catchService,
              fishService: widget.fishService,
              authToken: widget.authToken,
            ),
          ),
        )
        .then((value) {
          if (value == true) {
            _scheduleViewportLoad(_mapController.camera, force: true);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              onTap: _onMapTap,
              onPositionChanged: (camera, hasGesture) {
                _syncCameraZoom(camera.zoom);
                if (hasGesture) {
                  _scheduleViewportLoad(camera);
                }
              },
              onMapReady: _onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: _tileProvider,
                userAgentPackageName: 'com.example.mobile_app',
                // Tiles que falham são re-tentados ao voltarem à viewport e o
                // erro é agregado pelo AppLog (em vez de poluir o console).
                evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
                errorTileCallback: (tile, error, _) => AppLog.tileError(error),
              ),
              if (_lineStrings.isNotEmpty)
                PolylineLayer<Object>(polylines: _lineStrings),
              if (_polygons.isNotEmpty)
                PolygonLayer<Object>(polygons: _polygons),
              MarkerLayer(markers: _markers),
              if (!_markingMode) MarkerLayer(markers: _catchMarkers),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: cs.surface.withValues(alpha: 0.72),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          _buildHeaderPill(),
          if (_refreshing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
          if (_error != null) _buildErrorBanner(),
          if (!_markingMode &&
              _waterBodies.isEmpty &&
              _error == null &&
              _cameraZoom >= _minViewportZoom)
            _buildEmptyState(),
          if (_cameraZoom < _minViewportZoom) _buildZoomHint(),
          if (_markingMode) _buildNearestCard(),
          if (!_markingMode && _selectedBody != null) _buildSelectedBodyCard(),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: (_markingMode || _selectedBody != null) ? 190 : 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'map-mark-mode',
              backgroundColor: _markingMode ? AppColors.deep : cs.surface,
              foregroundColor: _markingMode ? cs.onPrimary : AppColors.primary,
              onPressed: _toggleMarkMode,
              child: Icon(_markingMode ? Icons.close : Icons.add),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'map-recenter',
              backgroundColor: cs.surface,
              foregroundColor: AppColors.primary,
              elevation: 3,
              onPressed: _recenter,
              child: const Icon(Icons.my_location),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPill() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.12),
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
                  // Branco intencional sobre gradiente de marca.
                  child: Icon(
                    _markingMode ? Icons.add_location_alt : Icons.water,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _markingMode ? 'Marcar ponto' : 'Corpos d\'água',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!_markingMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Card inferior exibido ao tocar um corpo d'água no mapa. Mesmo visual do
  /// card do modo "Marcar ponto", com CTA para criar registro ali.
  Widget _buildSelectedBodyCard() {
    final cs = Theme.of(context).colorScheme;
    final body = _selectedBody!;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _SelectionCard(
          background: cs.surface,
          borderColor: AppColors.primary.withValues(alpha: 0.2),
          child: _SelectionBody(
            body: body,
            onCreate: () => _openCatchFormForBody(body),
            distanceLabel: null,
            onClose: () => setState(() => _selectedBody = null),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 70),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _error!,
              style: TextStyle(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Nenhum corpo d\'água nesta área.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomHint() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Aproxime para ver os rios.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNearestCard() {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _nearestStatus == _NearestStatus.loading
              ? _SelectionCard(
                  key: const ValueKey('loading'),
                  background: cs.surface,
                  borderColor: AppColors.secondary.withValues(alpha: 0.3),
                  child: const _SelectionLoading(),
                )
              : _nearestStatus == _NearestStatus.found && _nearestBody != null
              ? _SelectionCard(
                  key: const ValueKey('found'),
                  background: cs.surface,
                  borderColor: AppColors.primary.withValues(alpha: 0.2),
                  child: _SelectionBody(
                    body: _nearestBody!,
                    onCreate: _openCatchForm,
                    distanceLabel: _formatDistance(
                      _nearestBody!.distanceMeters,
                    ),
                  ),
                )
              : _SelectionCard(
                  key: const ValueKey('empty'),
                  background: cs.surface,
                  borderColor: cs.error.withValues(alpha: 0.28),
                  child: _SelectionEmpty(
                    message: _nearestStatus == _NearestStatus.error
                        ? (_nearestError ?? 'Falha ao buscar água próxima.')
                        : _draftPoint == null
                        ? 'Toque no mapa para marcar ponto.'
                        : 'Nenhuma água num raio de 5 km.',
                    onCreate: null,
                  ),
                ),
        ),
      ),
    );
  }

  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '~?';
    if (distanceMeters < 1000) return '~${distanceMeters.round()} m';
    return '~${(distanceMeters / 1000).toStringAsFixed(1)} km';
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
    // Pins dos corpos d'água só aparecem com zoom suficiente; mais longe,
    // só a geometria fica visível para não poluir o mapa.
    final showBodyPins = !_markingMode && _cameraZoom >= _markerMinZoom;
    final markers = <Marker>[
      if (showBodyPins)
        for (final body in _waterBodies)
          Marker(
            point: body.centerLocation ?? _fallbackCenter(body),
            width: MapMarker.footprint,
            height: MapMarker.footprint,
            child: GestureDetector(
              onTap: () => _selectBody(body),
              child: MapMarker(
                kind: MapMarkerKind.waterBody,
                selected: _selectedBody?.id == body.id,
              ),
            ),
          ),
    ];

    if (_markingMode && _draftPoint != null) {
      markers.add(
        Marker(
          point: _draftPoint!,
          width: 44,
          height: 44,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => _moveDraftByDelta(details.delta),
            onPanEnd: (_) {
              final point = _draftPoint;
              if (point != null) {
                _scheduleNearestLookup(point);
              }
            },
            child: const _DraftPin(),
          ),
        ),
      );
    }

    return markers;
  }

  List<Marker> get _catchMarkers {
    if (_markingMode) return const [];
    return _catches.map((record) {
      final point =
          record.location ??
          record.waterBody.centerLocation ??
          _fallbackCenter(record.waterBody);
      return Marker(
        point: point,
        width: MapMarker.footprint,
        height: MapMarker.footprint,
        child: GestureDetector(
          onTap: () => _openCatchDetail(record),
          child: const MapMarker(kind: MapMarkerKind.catchRecord),
        ),
      );
    }).toList();
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
            .whereType<List<dynamic>>()
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
            .whereType<List<dynamic>>()
            .map((polygon) => _polygonFromCoordinates(polygon))
            .toList();
      }
    }

    return const [];
  }

  Polygon<Object> _polygonFromCoordinates(dynamic coordinates) {
    final rings = coordinates is List ? coordinates : const [];
    final outer = rings.isNotEmpty
        ? _latLngList(rings.first)
        : const <LatLng>[];
    final holes = rings.length > 1
        ? rings
              .skip(1)
              .map(_latLngList)
              .where((ring) => ring.isNotEmpty)
              .toList()
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
        .whereType<List<dynamic>>()
        .where((pair) => pair.length >= 2 && pair[0] is num && pair[1] is num)
        .map(
          (pair) =>
              LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
        )
        .toList();
  }
}

class _SelectionCard extends StatelessWidget {
  final Widget child;
  final Color background;
  final Color borderColor;

  const _SelectionCard({
    super.key,
    required this.child,
    required this.background,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _SelectionLoading extends StatelessWidget {
  const _SelectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              'Buscando corpo d\'água mais próximo...',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionBody extends StatelessWidget {
  final WaterBody body;
  final VoidCallback onCreate;

  /// Distância até o ponto marcado. Nulo quando o card vem de um toque direto
  /// no corpo d'água (sem ponto de referência).
  final String? distanceLabel;

  /// Quando informado, exibe um botão de fechar no canto do card.
  final VoidCallback? onClose;

  const _SelectionBody({
    required this.body,
    required this.onCreate,
    required this.distanceLabel,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  body.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (distanceLabel != null)
                Text(
                  distanceLabel!,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant, size: 22),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${body.waterType.label}${body.source == null ? "" : " • ${body.source}"}'
            '${body.osmId == null ? "" : " • OSM ${body.osmId}"}',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onCreate,
              child: const Text('Criar registro aqui'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionEmpty extends StatelessWidget {
  final String message;
  final VoidCallback? onCreate;

  const _SelectionEmpty({required this.message, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: onCreate == null ? cs.error : AppColors.secondary,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: cs.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onCreate,
              child: const Text('Criar registro aqui'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Handle de edição do ponto sendo marcado (modo "Marcar ponto"). É um alvo
/// circular vermelho com miolo branco — arrastável e propositalmente distinto
/// dos marcadores de dados (ver [MapMarker]), sinalizando "você está aqui".
class _DraftPin extends StatelessWidget {
  const _DraftPin();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.error,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.45),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // Miolo branco intencional, marcando o ponto exato.
        child: const Center(
          child: SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bbox {
  final double west;
  final double south;
  final double east;
  final double north;

  const _Bbox(this.west, this.south, this.east, this.north);

  factory _Bbox.fromBounds(LatLngBounds bounds, {double paddingFactor = 0}) {
    final latSpan = (bounds.north - bounds.south).abs();
    final lonSpan = (bounds.east - bounds.west).abs();
    final latPad = latSpan * paddingFactor;
    final lonPad = lonSpan * paddingFactor;
    return _Bbox(
      bounds.west - lonPad,
      bounds.south - latPad,
      bounds.east + lonPad,
      bounds.north + latPad,
    );
  }

  bool contains(LatLngBounds bounds) {
    return bounds.west >= west &&
        bounds.east <= east &&
        bounds.south >= south &&
        bounds.north <= north;
  }

  String toQueryString() => '$west,$south,$east,$north';
}
