import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/catch_record.dart';
import '../services/catch_service.dart';
import '../services/fish_service.dart';
import '../services/geocoding_service.dart';
import '../widgets/catch_post_card.dart';
import 'catch_detail_screen.dart';
import 'profile_screen.dart';

/// Região geográfica do feed: um bbox (minLon,minLat,maxLon,maxLat) e um rótulo.
class _Region {
  final String label;
  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;

  const _Region({
    required this.label,
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  });

  /// Região padrão (todo o Rio Grande do Sul) usada quando nenhum local foi
  /// buscado — assim o feed já aparece com algo.
  static const _Region defaultRegion = _Region(
    label: 'Rio Grande do Sul',
    minLon: -57.7,
    minLat: -33.9,
    maxLon: -49.5,
    maxLat: -27.0,
  );

  /// Constrói uma região "cidade + arredores" a partir de um ponto, com uma
  /// folga de ~0.4° (~40 km) em cada direção.
  factory _Region.around(String label, double lat, double lon) {
    const delta = 0.4;
    return _Region(
      label: label,
      minLon: lon - delta,
      minLat: lat - delta,
      maxLon: lon + delta,
      maxLat: lat + delta,
    );
  }

  String toBbox() => '$minLon,$minLat,$maxLon,$maxLat';
}

/// Aba "Posts": feed das últimas pescas de uma região. Por padrão mostra o RS;
/// o campo de busca resolve um local (ex.: "Lajeado") e passa a mostrar as
/// pescas daquela região.
class PostsScreen extends StatefulWidget {
  final CatchService? catchService;
  final FishService? fishService;
  final GeocodingService? geocodingService;
  final String? authToken;

  const PostsScreen({
    super.key,
    this.catchService,
    this.fishService,
    this.geocodingService,
    this.authToken,
  });

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  static const int _pageSize = 20;

  late final CatchService _service;
  late final GeocodingService _geocoder;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<CatchRecord> _records = [];

  _Region _region = _Region.defaultRegion;
  bool _loading = true;
  bool _loadingMore = false;
  bool _searching = false;
  bool _hasMore = true;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.catchService ?? CatchService();
    _geocoder = widget.geocodingService ?? GeocodingService();
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    _searchController.dispose();
    if (widget.catchService == null) _service.dispose();
    if (widget.geocodingService == null) _geocoder.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _hasMore = true;
      _records.clear();
    });

    try {
      final page = await _service.list(
        bbox: _region.toBbox(),
        page: 0,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _records.addAll(page);
        _loading = false;
        _hasMore = page.length == _pageSize;
        _page = 1;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _error != null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.list(
        bbox: _region.toBbox(),
        page: _page,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _records.addAll(page);
        _loadingMore = false;
        _hasMore = page.length == _pageSize;
        _page += 1;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients || !_hasMore) return;
    if (_scrollController.position.extentAfter < 420) {
      unawaited(_loadMore());
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _resetRegion();
      return;
    }

    setState(() => _searching = true);
    try {
      final places = await _geocoder.search(query);
      if (!mounted) return;
      setState(() => _searching = false);
      if (places.isEmpty) {
        _showSnack('Local "$query" não encontrado.');
        return;
      }
      final place = places.first;
      setState(() {
        _region = _Region.around(place.shortName, place.lat, place.lon);
      });
      await _loadInitial();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      _showSnack(e.message);
    }
  }

  void _resetRegion() {
    _searchController.clear();
    setState(() => _region = _Region.defaultRegion);
    unawaited(_loadInitial());
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openRecord(CatchRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CatchDetailScreen(
          initialRecord: record,
          catchService: widget.catchService,
          fishService: widget.fishService,
          authToken: widget.authToken,
        ),
      ),
    );
  }

  void _openAuthorProfile(CatchRecord record) {
    final author = record.author;
    if (author == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: author.id,
          authToken: widget.authToken,
          catchService: widget.catchService ?? _service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    final usingDefault = identical(_region, _Region.defaultRegion);
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.waterGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Posts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.place, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _region.label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!usingDefault)
                    GestureDetector(
                      onTap: _resetRegion,
                      child: Text(
                        'Limpar',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchLocation(),
                decoration: InputDecoration(
                  hintText: 'Buscar local (ex.: Lajeado)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _searchLocation,
                        ),
                  filled: true,
                  fillColor: cs.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          FeedStateCard(
            icon: Icons.cloud_off,
            title: 'Falha ao carregar posts',
            message: _error!,
            actionLabel: 'Tentar novamente',
            onAction: _loadInitial,
          ),
        ],
      );
    }

    if (_records.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            FeedStateCard(
              icon: Icons.inbox_outlined,
              title: 'Nenhuma pesca em ${_region.label}.',
              message: 'Tente buscar outro local ou amplie a região.',
              actionLabel: 'Atualizar',
              onAction: _loadInitial,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _records.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _records.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final record = _records[index];
          return CatchPostCard(
            record: record,
            authToken: widget.authToken,
            uploadUrl: record.photos.isEmpty
                ? null
                : _service.uploadUrl(record.photos.first.filePath),
            authorAvatarUrl: record.author?.avatarPath == null
                ? null
                : _service.uploadUrl(record.author!.avatarPath!),
            onTap: () => _openRecord(record),
            onAuthorTap: record.author == null
                ? null
                : () => _openAuthorProfile(record),
          );
        },
      ),
    );
  }
}
