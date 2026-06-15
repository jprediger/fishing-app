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
import '../models/establishment.dart';
import '../models/water_body.dart';
import '../services/catch_service.dart';
import '../services/establishment_service.dart';
import '../services/fish_service.dart';
import '../services/location_service.dart';
import '../services/water_body_service.dart';
import '../widgets/map_marker.dart';
import 'catch_detail_screen.dart';
import 'catch_feed_screen.dart';
import 'catch_form_screen.dart';

class MapScreen extends StatefulWidget {
  final WaterBodyService? waterBodyService;
  final FishService? fishService;
  final CatchService? catchService;
  final EstablishmentService? establishmentService;
  final String? authToken;
  final bool showTiles;
  final double? debugInitialZoom;
  final LocationService? locationService;

  /// Estabelecimento a focar no mapa (vindo da aba "Locais"). Quando muda para
  /// um valor não nulo, o mapa centraliza nele e exibe um marcador.
  final Establishment? focusEstablishment;

  /// Test hook: pre-seeds draft point when mark mode opens.
  final LatLng? debugInitialDraftPoint;

  /// Test hook: observa quando o mapa centraliza na localização do usuário.
  final ValueChanged<LatLng>? debugOnUserLocationCentered;

  const MapScreen({
    super.key,
    this.waterBodyService,
    this.fishService,
    this.catchService,
    this.establishmentService,
    this.authToken,
    this.showTiles = true,
    this.debugInitialZoom,
    this.locationService,
    this.focusEstablishment,
    this.debugInitialDraftPoint,
    this.debugOnUserLocationCentered,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _NearestStatus { idle, loading, found, notFound, error }

class _MapScreenState extends State<MapScreen> {
  static const LatLng _initialCenter = LatLng(-30.0846, -51.2645);
  static const double _initialZoom = 11.5;

  /// Abaixo deste zoom nenhum corpo d'água é carregado/renderizado — em visão
  /// regional a tela fica limpa. Acima, a geometria passa a aparecer.
  static const double _minViewportZoom = 11.0;

  /// Acima deste zoom os pins dos corpos d'água aparecem. Abaixo, só a
  /// geometria (linhas/polígonos) fica visível para não poluir a tela.
  static const double _markerMinZoom = 15.0;

  static const double _viewportPadding = 0.2;
  static const double _userFocusZoom = 15.5;
  static const Duration _userLocationMaxAge = Duration(minutes: 3);

  /// Folga aplicada à viewport visível ao decidir quais corpos desenhar
  /// (culling). Mantém corpos junto às bordas visíveis enquanto o usuário
  /// arrasta, evitando "pop-in" no limite da tela.
  static const double _cullPadding = 0.15;

  final MapController _mapController = MapController();
  final CancellableNetworkTileProvider _tileProvider =
      CancellableNetworkTileProvider();
  Timer? _viewportDebounce;
  Timer? _nearestDebounce;
  Timer? _catchDebounce;
  late final WaterBodyService _service;
  late final CatchService _catchService;
  late final LocationService _locationService;

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
  int? _loadedZoom;

  /// Viewport visível atual, usada para o culling client-side. Atualizada a
  /// cada movimento de câmera (com limiar para não rebuildar a cada pixel).
  LatLngBounds? _visibleBounds;

  /// Cache de bounding box por corpo (id -> bbox), evitando recalcular a
  /// extensão da geometria a cada rebuild durante o culling.
  final Map<int, _Bbox> _bodyBoundsCache = {};
  LatLng? _draftPoint;
  WaterBody? _nearestBody;
  _NearestStatus _nearestStatus = _NearestStatus.idle;
  List<WaterBody> _waterBodies = const [];
  List<CatchRecord> _catches = const [];

  /// Zoom usado ao centralizar num estabelecimento vindo da aba "Locais".
  static const double _establishmentFocusZoom = 14.0;

  late final EstablishmentService _establishmentService;
  bool _mapReady = false;

  /// Camadas exibíveis no mapa, controladas pelo painel de camadas.
  bool _showWaterBodies = true;
  bool _showCatches = true;
  bool _showEstablishments = false;
  bool _layersPanelOpen = false;

  List<Establishment> _establishments = const [];

  /// Estabelecimento selecionado (por toque no marcador ou vindo de "Locais").
  Establishment? _selectedEstablishment;
  LatLng? _userLocation;
  DateTime? _userLocationFetchedAt;
  bool _locatingUser = false;

  @override
  void initState() {
    super.initState();
    _service = widget.waterBodyService ?? WaterBodyService();
    _catchService = widget.catchService ?? CatchService();
    _establishmentService =
        widget.establishmentService ?? EstablishmentService();
    _locationService =
        widget.locationService ?? const GeolocatorLocationService();
    unawaited(_hydrateUserLocationIfAllowed());
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focusEstablishment;
    if (focus != null && !identical(focus, oldWidget.focusEstablishment)) {
      _applyEstablishmentFocus(focus);
    }
  }

  @override
  void dispose() {
    _viewportDebounce?.cancel();
    _nearestDebounce?.cancel();
    _catchDebounce?.cancel();
    if (widget.waterBodyService == null) _service.dispose();
    if (widget.catchService == null) _catchService.dispose();
    if (widget.establishmentService == null) _establishmentService.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    if (!mounted) return;
    _mapReady = true;
    _syncCamera(_mapController.camera);
    _scheduleViewportLoad(_mapController.camera, force: true);
    final focus = widget.focusEstablishment;
    if (focus != null) _applyEstablishmentFocus(focus);
  }

  /// Centraliza num estabelecimento (vindo de "Locais"), liga a camada e o
  /// seleciona. Garante que a lista esteja carregada para exibir os demais.
  void _applyEstablishmentFocus(Establishment establishment) {
    if (!mounted) return;
    setState(() {
      _showEstablishments = true;
      _selectedEstablishment = establishment;
    });
    unawaited(_loadEstablishments());
    final location = establishment.location;
    if (location != null && _mapReady) {
      _mapController.move(location, _establishmentFocusZoom);
    }
  }

  void _setShowWaterBodies(bool value) {
    setState(() {
      _showWaterBodies = value;
      if (!value) _selectedBody = null;
    });
  }

  void _setShowCatches(bool value) {
    setState(() => _showCatches = value);
  }

  void _setShowEstablishments(bool value) {
    setState(() {
      _showEstablishments = value;
      if (!value) _selectedEstablishment = null;
    });
    if (value) unawaited(_loadEstablishments());
  }

  /// Carrega os estabelecimentos uma vez (o conjunto é pequeno). Mantém em
  /// cache; falhas são silenciosas para não atrapalhar o mapa.
  Future<void> _loadEstablishments() async {
    if (_establishments.isNotEmpty) return;
    try {
      final list = await _establishmentService.search(limit: 500);
      if (!mounted) return;
      setState(() => _establishments = list);
    } on ApiException {
      // Sem estabelecimentos: a camada simplesmente fica vazia.
    }
  }

  Future<void> _hydrateUserLocationIfAllowed() async {
    final permission = await _locationService.checkPermission();
    if (!mounted || !permission.isGranted) return;
    await _resolveUserLocation(
      requestPermission: false,
      moveMap: false,
      useCache: false,
      showFeedback: false,
    );
  }

  void _selectEstablishment(Establishment establishment) {
    setState(() => _selectedEstablishment = establishment);
  }

  /// Sincroniza zoom e viewport visível com a câmera. Dispara rebuild (e novo
  /// culling) só quando o zoom muda ou a viewport se desloca o suficiente,
  /// evitando uma cascata de setState a cada frame do gesto.
  void _syncCamera(MapCamera camera) {
    if (!mounted) return;
    final zoomChanged = (camera.zoom - _cameraZoom).abs() >= 0.01;
    final bounds = camera.visibleBounds;
    final boundsChanged = _boundsMovedEnough(bounds);
    if (!zoomChanged && !boundsChanged) return;
    setState(() {
      _cameraZoom = camera.zoom;
      _visibleBounds = bounds;
    });
  }

  /// Verdadeiro quando a viewport mudou mais que ~5% do seu próprio span em
  /// qualquer borda — limiar que mantém o culling fluido sem rebuildar a cada
  /// pixel arrastado.
  bool _boundsMovedEnough(LatLngBounds bounds) {
    final current = _visibleBounds;
    if (current == null) return true;
    final lonSpan = (bounds.east - bounds.west).abs();
    final latSpan = (bounds.north - bounds.south).abs();
    final lonEps = lonSpan * 0.05;
    final latEps = latSpan * 0.05;
    return (bounds.west - current.west).abs() > lonEps ||
        (bounds.east - current.east).abs() > lonEps ||
        (bounds.south - current.south).abs() > latEps ||
        (bounds.north - current.north).abs() > latEps;
  }

  void _scheduleViewportLoad(MapCamera camera, {bool force = false}) {
    _syncCamera(camera);

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
        _loadedZoom = null;
      });
      return;
    }

    final visibleBounds = camera.visibleBounds;
    final zoom = camera.zoom.round();
    // Pula o fetch só quando o que já está em memória cobre a viewport E
    // continua na mesma faixa de simplificação. Ao dar zoom in cruzando uma
    // faixa, refazemos para trazer geometria mais detalhada.
    if (!force &&
        _loadedViewport?.contains(visibleBounds) == true &&
        _loadedZoom != null &&
        _toleranceBand(zoom) == _toleranceBand(_loadedZoom!)) {
      return;
    }

    _viewportDebounce?.cancel();
    final seq = ++_viewportRequestSeq;
    final target = _Bbox.fromBounds(
      visibleBounds,
      paddingFactor: _viewportPadding,
    );

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
        _loadedZoom = zoom;
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

    unawaited(_loadCatches(target: target, seq: seq));
  }

  Future<void> _loadCatches({required _Bbox target, required int seq}) async {
    final currentSeq = ++_catchRequestSeq;
    try {
      final catches = await _catchService.list(
        bbox: target.toQueryString(),
        page: 0,
        size: 200,
      );
      if (!mounted || currentSeq != _catchRequestSeq) {
        return;
      }
      setState(() => _catches = catches);
    } on ApiException {
      if (!mounted || currentSeq != _catchRequestSeq) {
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

    setState(() {
      _markingMode = true;
      _layersPanelOpen = false;
    });
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

  bool get _hasFreshUserLocation {
    final location = _userLocation;
    final fetchedAt = _userLocationFetchedAt;
    if (location == null || fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) <= _userLocationMaxAge;
  }

  Future<void> _recenter() async {
    await _resolveUserLocation(
      requestPermission: true,
      moveMap: true,
      useCache: true,
      showFeedback: true,
    );
  }

  Future<LatLng?> _resolveUserLocation({
    required bool requestPermission,
    required bool moveMap,
    required bool useCache,
    required bool showFeedback,
  }) async {
    if (useCache && _hasFreshUserLocation) {
      final cached = _userLocation!;
      if (moveMap) _centerOnUser(cached);
      return cached;
    }

    if (_locatingUser) return _userLocation;

    if (!mounted) return _userLocation;
    setState(() => _locatingUser = true);

    try {
      final enabled = await _locationService.isServiceEnabled();
      if (!enabled) {
        if (showFeedback) {
          _showLocationMessage(
            'Ative a localização do dispositivo para usar este recurso.',
          );
        }
        return null;
      }

      var permission = await _locationService.checkPermission();
      if (!permission.isGranted && requestPermission) {
        permission = await _locationService.requestPermission();
      }
      if (!permission.isGranted) {
        if (showFeedback) {
          _showLocationMessage(_permissionMessage(permission));
        }
        return null;
      }

      final location = await _locationService.getCurrentLocation();
      if (!mounted || location == null) return _userLocation;
      setState(() {
        _userLocation = location.coordinates;
        _userLocationFetchedAt = location.timestamp ?? DateTime.now();
      });
      if (moveMap) _centerOnUser(location.coordinates);
      return location.coordinates;
    } on LocationException catch (e) {
      if (showFeedback) _showLocationMessage(e.message);
      return null;
    } finally {
      if (mounted) {
        setState(() => _locatingUser = false);
      }
    }
  }

  void _centerOnUser(LatLng point) {
    if (!_mapReady) return;
    final zoom = max(_cameraZoom, _userFocusZoom).toDouble();
    _mapController.move(point, zoom);
    widget.debugOnUserLocationCentered?.call(point);
    _scheduleViewportLoad(_mapController.camera, force: true);
  }

  String _permissionMessage(AppLocationPermission permission) {
    switch (permission) {
      case AppLocationPermission.deniedForever:
        return 'Permita a localização nas configurações do sistema para centralizar você no mapa.';
      case AppLocationPermission.denied:
        return 'Permita o acesso à localização para centralizar você no mapa.';
      case AppLocationPermission.whileInUse:
      case AppLocationPermission.always:
        return 'Não foi possível obter sua localização agora.';
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  double get _effectiveInitialZoom => widget.debugInitialZoom ?? _initialZoom;

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
  void _refreshAfterCatchSaved(Object? value) {
    if (!mounted) return;
    if (value is CatchRecord) {
      setState(() => _selectedBody = null);
      _exitMarkMode();
    }
    _scheduleViewportLoad(_mapController.camera, force: true);
  }

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
        .then(_refreshAfterCatchSaved);
  }

  void _openCatchFeed(WaterBody body) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CatchFeedScreen(
              body: body,
              catchService: _catchService,
              fishService: widget.fishService,
              authToken: widget.authToken,
            ),
          ),
        )
        .then(_refreshAfterCatchSaved);
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
        .then(_refreshAfterCatchSaved);
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
    // Culling: resolve uma única vez por build quais corpos estão na viewport
    // e deriva as camadas a partir disso, evitando refiltrar/reparsear tudo.
    final visible = _visibleBodies;
    final lineStrings = _lineStringsFor(visible);
    final polygons = _polygonsFor(visible);
    final markers = _markersFor(visible);
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _effectiveInitialZoom,
              onTap: _onMapTap,
              onPositionChanged: (camera, hasGesture) {
                _syncCamera(camera);
                if (hasGesture) {
                  _scheduleViewportLoad(camera);
                }
              },
              onMapReady: _onMapReady,
            ),
            children: [
              if (widget.showTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: _tileProvider,
                  userAgentPackageName: 'com.example.mobile_app',
                  // Tiles que falham são re-tentados ao voltarem à viewport e o
                  // erro é agregado pelo AppLog (em vez de poluir o console).
                  evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
                  errorTileCallback: (tile, error, _) =>
                      AppLog.tileError(error),
                ),
              if (_showWaterBodies && lineStrings.isNotEmpty)
                PolylineLayer<Object>(polylines: lineStrings),
              if (_showWaterBodies && polygons.isNotEmpty)
                PolygonLayer<Object>(polygons: polygons),
              MarkerLayer(markers: markers),
              if (!_markingMode && _userMarkers.isNotEmpty)
                MarkerLayer(markers: _userMarkers),
              if (!_markingMode && _showCatches)
                MarkerLayer(markers: _catchMarkers),
              if (!_markingMode) MarkerLayer(markers: _establishmentMarkers),
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
              _showWaterBodies &&
              _waterBodies.isEmpty &&
              _error == null &&
              _cameraZoom >= _minViewportZoom)
            _buildEmptyState(),
          if (_layersPanelOpen && !_markingMode) _buildLayersPanel(),
          if (_cameraZoom < _minViewportZoom) _buildZoomHint(),
          if (_markingMode) _buildNearestCard(),
          if (!_markingMode && _selectedBody != null) _buildSelectedBodyCard(),
          if (!_markingMode &&
              _selectedBody == null &&
              _selectedEstablishment != null)
            _buildSelectedEstablishmentCard(),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom:
              (_markingMode ||
                  _selectedBody != null ||
                  _selectedEstablishment != null)
              ? 190
              : 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_markingMode)
              FloatingActionButton.small(
                heroTag: 'map-layers',
                backgroundColor: _layersPanelOpen ? AppColors.deep : cs.surface,
                foregroundColor: _layersPanelOpen
                    ? cs.onPrimary
                    : AppColors.primary,
                tooltip: 'Camadas do mapa',
                onPressed: () =>
                    setState(() => _layersPanelOpen = !_layersPanelOpen),
                child: const Icon(Icons.layers),
              ),
            if (!_markingMode) const SizedBox(height: 12),
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
              tooltip: 'Centralizar em mim',
              child: _locatingUser
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.my_location),
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
            onViewRecords: () => _openCatchFeed(body),
            distanceLabel: null,
            onClose: () => setState(() => _selectedBody = null),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedEstablishmentCard() {
    final cs = Theme.of(context).colorScheme;
    final establishment = _selectedEstablishment!;
    final address = establishment.address;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _SelectionCard(
          background: cs.surface,
          borderColor: AppColors.markerEstablishment.withValues(alpha: 0.35),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.markerEstablishment.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store, color: AppColors.deep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      establishment.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address == null || address.isEmpty
                          ? establishment.category.label
                          : '${establishment.category.label} · $address',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedEstablishment = null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayersPanel() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 200),
          child: Container(
            width: 240,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Camadas',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () =>
                            setState(() => _layersPanelOpen = false),
                      ),
                    ],
                  ),
                ),
                _layerSwitch(
                  color: AppColors.markerWaterBody,
                  icon: Icons.water_drop,
                  label: 'Corpos d\'água',
                  value: _showWaterBodies,
                  onChanged: _setShowWaterBodies,
                ),
                _layerSwitch(
                  color: AppColors.markerCatch,
                  icon: Icons.phishing,
                  label: 'Pescas',
                  value: _showCatches,
                  onChanged: _setShowCatches,
                ),
                _layerSwitch(
                  color: AppColors.markerEstablishment,
                  icon: Icons.store,
                  label: 'Estabelecimentos',
                  value: _showEstablishments,
                  onChanged: _setShowEstablishments,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _layerSwitch({
    required Color color,
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: CircleAvatar(
        radius: 14,
        backgroundColor: color,
        child: Icon(icon, size: 15, color: Colors.white),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
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
                    onViewRecords: () => _openCatchFeed(_nearestBody!),
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

  /// Faixa de simplificação por zoom — espelha `zoomToTolerance` do backend.
  /// Usada para refazer o fetch quando o zoom cruza para outra faixa.
  int _toleranceBand(int zoom) {
    if (zoom <= 8) return 0;
    if (zoom <= 10) return 1;
    if (zoom <= 13) return 2;
    return 3;
  }

  /// Bounding box da geometria de um corpo (com cache por id). Percorre as
  /// coordenadas GeoJSON achando os extremos de lat/lon.
  _Bbox? _bodyBounds(WaterBody body) {
    final cached = _bodyBoundsCache[body.id];
    if (cached != null) return cached;

    double? minLat, minLon, maxLat, maxLon;
    void visit(dynamic node) {
      if (node is! List || node.isEmpty) return;
      // Uma posição GeoJSON é [lon, lat]; um container é lista de listas.
      if (node[0] is num && node.length >= 2 && node[1] is num) {
        final lon = (node[0] as num).toDouble();
        final lat = (node[1] as num).toDouble();
        minLon = minLon == null ? lon : min(minLon!, lon);
        maxLon = maxLon == null ? lon : max(maxLon!, lon);
        minLat = minLat == null ? lat : min(minLat!, lat);
        maxLat = maxLat == null ? lat : max(maxLat!, lat);
        return;
      }
      for (final child in node) {
        visit(child);
      }
    }

    visit(body.geometry['coordinates']);
    if (minLat == null) {
      // Geometria sem coordenadas: cai no centro, se houver.
      final center = body.centerLocation;
      if (center == null) return null;
      final b = _Bbox(
        center.longitude,
        center.latitude,
        center.longitude,
        center.latitude,
      );
      _bodyBoundsCache[body.id] = b;
      return b;
    }

    final bounds = _Bbox(minLon!, minLat!, maxLon!, maxLat!);
    _bodyBoundsCache[body.id] = bounds;
    return bounds;
  }

  /// Corpos que intersectam a viewport visível atual (com folga). É a base do
  /// culling: só estes viram linhas/polígonos/pins, mantendo o render leve
  /// mesmo com centenas de corpos em memória.
  List<WaterBody> get _visibleBodies {
    final bounds = _visibleBounds;
    if (bounds == null) return _waterBodies;
    final viewport = _Bbox.fromBounds(bounds, paddingFactor: _cullPadding);
    return _waterBodies
        .where((body) {
          final bb = _bodyBounds(body);
          return bb == null || bb.intersects(viewport);
        })
        .toList(growable: false);
  }

  List<Polyline<Object>> _lineStringsFor(List<WaterBody> bodies) {
    final lines = <Polyline<Object>>[];
    for (final body in bodies) {
      lines.addAll(_linesForBody(body));
    }
    return lines;
  }

  List<Polygon<Object>> _polygonsFor(List<WaterBody> bodies) {
    final polygons = <Polygon<Object>>[];
    for (final body in bodies) {
      polygons.addAll(_polygonsForBody(body));
    }
    return polygons;
  }

  List<Marker> _markersFor(List<WaterBody> bodies) {
    // Pins dos corpos d'água só aparecem com zoom suficiente; mais longe,
    // só a geometria fica visível para não poluir o mapa.
    final showBodyPins =
        !_markingMode && _showWaterBodies && _cameraZoom >= _markerMinZoom;
    final markers = <Marker>[
      if (showBodyPins)
        for (final body in bodies)
          Marker(
            point: body.centerLocation ?? _fallbackCenter(body),
            width: MapMarker.footprint,
            height: MapMarker.footprint,
            child: GestureDetector(
              onTap: () => _selectBody(body),
              child: MapMarker(
                kind: MapMarkerKind.waterBody,
                selected: _selectedBody?.id == body.id,
                badgeCount: body.catchCount,
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
    return _catches
        .where((record) {
          return record.locationVisibility == LocationVisibility.exact &&
              record.location != null;
        })
        .map((record) {
          return Marker(
            point: record.location!,
            width: MapMarker.footprint,
            height: MapMarker.footprint,
            child: GestureDetector(
              onTap: () => _openCatchDetail(record),
              child: MapMarker(
                kind: record.mine
                    ? MapMarkerKind.catchRecordMine
                    : MapMarkerKind.catchRecord,
              ),
            ),
          );
        })
        .toList();
  }

  List<Marker> get _userMarkers {
    final point = _userLocation;
    if (point == null) return const [];
    return [
      Marker(
        point: point,
        width: MapMarker.footprint,
        height: MapMarker.footprint,
        child: const IgnorePointer(
          child: MapMarker(
            key: ValueKey('user-location-marker'),
            kind: MapMarkerKind.user,
          ),
        ),
      ),
    ];
  }

  List<Marker> get _establishmentMarkers {
    if (_markingMode) return const [];
    if (!_showEstablishments && _selectedEstablishment == null) {
      return const [];
    }

    final items = <Establishment>[];
    if (_showEstablishments) items.addAll(_establishments);
    final selected = _selectedEstablishment;
    if (selected != null && !items.any((e) => e.id == selected.id)) {
      items.add(selected);
    }

    return items
        .where((establishment) => establishment.location != null)
        .map(
          (establishment) => Marker(
            point: establishment.location!,
            width: MapMarker.footprint,
            height: MapMarker.footprint,
            child: GestureDetector(
              onTap: () => _selectEstablishment(establishment),
              child: MapMarker(
                kind: MapMarkerKind.establishment,
                selected: _selectedEstablishment?.id == establishment.id,
              ),
            ),
          ),
        )
        .toList();
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
  final VoidCallback onViewRecords;

  /// Distância até o ponto marcado. Nulo quando o card vem de um toque direto
  /// no corpo d'água (sem ponto de referência).
  final String? distanceLabel;

  /// Quando informado, exibe um botão de fechar no canto do card.
  final VoidCallback? onClose;

  const _SelectionBody({
    required this.body,
    required this.onCreate,
    required this.onViewRecords,
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onViewRecords,
                  child: Text(
                    body.catchCount == null
                        ? 'Ver registros'
                        : 'Ver registros (${body.catchCount})',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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

  /// Verdadeiro quando este bbox e [other] se sobrepõem em qualquer ponto.
  bool intersects(_Bbox other) {
    return west <= other.east &&
        east >= other.west &&
        south <= other.north &&
        north >= other.south;
  }

  String toQueryString() => '$west,$south,$east,$north';
}
