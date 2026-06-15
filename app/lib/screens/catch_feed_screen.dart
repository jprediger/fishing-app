// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/catch_record.dart';
import '../models/water_body.dart';
import '../services/catch_service.dart';
import '../services/fish_service.dart';
import '../widgets/catch_post_card.dart';
import 'catch_detail_screen.dart';
import 'profile_screen.dart';

class CatchFeedScreen extends StatefulWidget {
  final WaterBody body;
  final CatchService? catchService;
  final FishService? fishService;
  final String? authToken;

  const CatchFeedScreen({
    super.key,
    required this.body,
    this.catchService,
    this.fishService,
    this.authToken,
  });

  @override
  State<CatchFeedScreen> createState() => _CatchFeedScreenState();
}

class _CatchFeedScreenState extends State<CatchFeedScreen> {
  static const int _pageSize = 20;

  late final CatchService _service;
  final ScrollController _scrollController = ScrollController();
  final List<CatchRecord> _records = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _loadMoreError;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.catchService ?? CatchService();
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    if (widget.catchService == null) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadMoreError = null;
      _page = 0;
      _hasMore = true;
      _records.clear();
    });

    try {
      final page = await _service.listByWaterBody(
        waterBodyId: widget.body.id,
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Falha ao carregar feed.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading ||
        _loadingMore ||
        !_hasMore ||
        _error != null ||
        _loadMoreError != null) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final page = await _service.listByWaterBody(
        waterBodyId: widget.body.id,
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = error is ApiException
            ? error.message
            : 'Falha ao carregar mais registros.';
      });
    }
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients || !_hasMore) return;
    if (_scrollController.position.extentAfter < 420) {
      unawaited(_loadMore());
    }
  }

  Future<void> _retry() => _loadInitial();

  Future<void> _retryMore() async {
    setState(() => _loadMoreError = null);
    await _loadMore();
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.body.name)),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading && _records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          FeedStateCard(
            icon: Icons.error_outline,
            title: 'Falha ao carregar feed',
            message: _error!,
            actionLabel: 'Tentar novamente',
            onAction: _retry,
          ),
        ],
      );
    }

    if (_records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          FeedStateCard(
            icon: Icons.inbox_outlined,
            title: 'Nenhum registro neste corpo d\'água ainda.',
            message: 'Seja o primeiro a postar uma captura aqui.',
            actionLabel: 'Atualizar',
            onAction: _retry,
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount:
          _records.length + (_loadingMore || _loadMoreError != null ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _records.length) {
          if (_loadMoreError != null) {
            return FeedStateCard(
              icon: Icons.sync_problem,
              title: 'Falha ao carregar mais registros',
              message: _loadMoreError!,
              actionLabel: 'Tentar novamente',
              onAction: _retryMore,
            );
          }
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
    );
  }
}

class _CatchPostCard extends StatelessWidget {
  final CatchRecord record;
  final String? authToken;
  final String? uploadUrl;
  final VoidCallback onTap;

  const _CatchPostCard({
    required this.record,
    required this.authToken,
    required this.uploadUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final author = record.mine
        ? 'Você'
        : (record.author?.name ?? 'Autor desconhecido');
    final localLabel =
        record.location == null ||
            (!record.mine &&
                record.locationVisibility == LocationVisibility.riverOnly)
        ? 'Local aproximado'
        : 'Ponto exato';

    return Material(
      color: cs.surface,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(uploadUrl: uploadUrl, authToken: authToken),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              author,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            _formatDate(record.caughtAt),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.species.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (record.weightGrams != null)
                            _MiniPill(text: '${record.weightGrams} g'),
                          if (record.lengthMm != null)
                            _MiniPill(text: '${record.lengthMm} mm'),
                          _MiniPill(text: localLabel),
                        ],
                      ),
                      if (record.description != null &&
                          record.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          record.description!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _Thumbnail extends StatelessWidget {
  final String? uploadUrl;
  final String? authToken;

  const _Thumbnail({required this.uploadUrl, required this.authToken});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (uploadUrl == null) {
      return Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.photo, color: cs.onSurfaceVariant),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Image.network(
          uploadUrl!,
          fit: BoxFit.cover,
          headers: authToken == null
              ? null
              : {'Authorization': 'Bearer $authToken'},
          errorBuilder: (context, error, stackTrace) => Container(
            color: cs.surfaceContainerHighest,
            child: Icon(Icons.broken_image, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;

  const _MiniPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _FeedStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _FeedStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 38, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
