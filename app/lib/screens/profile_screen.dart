import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../models/catch_record.dart';
import '../models/user_profile.dart';
import '../services/api_exception.dart';
import '../services/auth_http_client.dart';
import '../services/catch_service.dart';
import '../services/profile_service.dart';
import '../state/auth_controller.dart';
import '../widgets/catch_post_card.dart';
import 'catch_detail_screen.dart';
import 'edit_profile_screen.dart';

/// Tela única de perfil: próprio usuário ou perfil de outra pessoa.
class ProfileScreen extends StatefulWidget {
  final int? userId;
  final AuthController? auth;
  final String? authToken;
  final CatchService? catchService;
  final ProfileService? profileService;

  const ProfileScreen({
    super.key,
    this.userId,
    this.auth,
    this.authToken,
    this.catchService,
    this.profileService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const int _pageSize = 20;

  late final ScrollController _scrollController = ScrollController();
  late final CatchService _catchService;
  late final ProfileService _profileService;
  late final bool _ownsCatchService;
  late final bool _ownsProfileService;

  final List<CatchRecord> _records = [];
  UserProfile? _profile;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _loadMoreError;
  int _page = 0;

  String? get _token => widget.auth?.token ?? widget.authToken;

  int? get _effectiveUserId => widget.userId ?? widget.auth?.user?.id;

  bool get _isOwnProfile =>
      widget.auth != null &&
      _effectiveUserId != null &&
      widget.auth?.user?.id == _effectiveUserId;

  @override
  void initState() {
    super.initState();
    if (widget.catchService != null) {
      _catchService = widget.catchService!;
      _ownsCatchService = false;
    } else {
      _catchService = CatchService(client: _buildClient());
      _ownsCatchService = true;
    }
    if (widget.profileService != null) {
      _profileService = widget.profileService!;
      _ownsProfileService = false;
    } else {
      _profileService = ProfileService(client: _buildClient());
      _ownsProfileService = true;
    }
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_loadInitial());
  }

  http.Client _buildClient() {
    return AuthHttpClient(
      tokenProvider: () => _token,
      onUnauthorized: widget.auth?.onUnauthorized ?? () {},
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    if (_ownsCatchService) {
      _catchService.dispose();
    }
    if (_ownsProfileService) {
      _profileService.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final token = _token;
    final userId = _effectiveUserId;
    if (token == null || userId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Sessão indisponível.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _loadMoreError = null;
      _page = 0;
      _hasMore = true;
      _records.clear();
    });

    try {
      final results = await Future.wait([
        _profileService.fetchProfile(token, userId),
        _catchService.listByUser(userId: userId, page: 0, size: _pageSize),
      ]);
      if (!mounted) return;
      final profile = results[0] as UserProfile;
      final page = results[1] as List<CatchRecord>;
      setState(() {
        _profile = profile;
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
            : 'Falha ao carregar perfil.';
      });
    }
  }

  Future<void> _loadMore() async {
    final userId = _effectiveUserId;
    if (_loading ||
        _loadingMore ||
        !_hasMore ||
        _error != null ||
        _loadMoreError != null ||
        userId == null) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final page = await _catchService.listByUser(
        userId: userId,
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

  Future<void> _openRecord(CatchRecord record) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => CatchDetailScreen(
          initialRecord: record,
          catchService: widget.catchService ?? _catchService,
          authToken: _token,
        ),
      ),
    );
    if (!mounted) return;
    // CatchDetailScreen retorna `true` ao excluir e o registro atualizado ao
    // editar. Em ambos os casos recarregamos para refletir lista e contadores.
    if (result == true || result is CatchRecord) {
      await _loadInitial();
    }
  }

  void _openEdit() {
    final auth = widget.auth;
    if (auth == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EditProfileScreen(auth: auth)))
        .then((_) {
          if (mounted) {
            unawaited(_loadInitial());
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    if (_loading && profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null && profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            FeedStateCard(
              icon: Icons.error_outline,
              title: 'Falha ao carregar perfil',
              message: _error!,
              actionLabel: 'Tentar novamente',
              onAction: _retry,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.name ?? 'Perfil'),
        actions: _isOwnProfile
            ? [
                IconButton(
                  onPressed: _openEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar perfil',
                ),
                IconButton(
                  onPressed: () => widget.auth?.logout(),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sair',
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _retry,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                profile: profile,
                authToken: _token,
                uploadUrl: profile?.avatarPath == null
                    ? null
                    : _catchService.uploadUrl(profile!.avatarPath!),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: _StatsRow(profile: profile),
              ),
            ),
            if (_records.isEmpty && !_loadingMore && _loadMoreError == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: FeedStateCard(
                      icon: Icons.inbox_outlined,
                      title: 'Nenhum registro ainda.',
                      message: _isOwnProfile
                          ? 'Seu perfil ainda não tem capturas publicadas.'
                          : 'Essa pessoa ainda não publicou capturas.',
                      actionLabel: 'Atualizar',
                      onAction: _retry,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final isSeparator = index.isOdd;
                      final itemIndex = index ~/ 2;
                      final hasTrailingWidget =
                          _loadingMore || _loadMoreError != null;

                      if (isSeparator) {
                        if (itemIndex >= _records.length - 1 &&
                            !hasTrailingWidget) {
                          return const SizedBox.shrink();
                        }
                        return const SizedBox(height: 12);
                      }

                      if (itemIndex >= _records.length) {
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

                      final record = _records[itemIndex];
                      return CatchPostCard(
                        record: record,
                        authToken: _token,
                        uploadUrl: record.photos.isEmpty
                            ? null
                            : _catchService.uploadUrl(
                                record.photos.first.filePath,
                              ),
                        showAuthor: false,
                        onTap: () => _openRecord(record),
                      );
                    },
                    childCount:
                        _records.isEmpty &&
                            (_loadingMore || _loadMoreError != null)
                        ? 1
                        : _records.length * 2 -
                              1 +
                              (_loadingMore || _loadMoreError != null ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile? profile;
  final String? uploadUrl;
  final String? authToken;

  const _ProfileHeader({
    required this.profile,
    required this.uploadUrl,
    required this.authToken,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile?.name ?? 'Pescador';
    final role = profile?.role.label ?? '';
    final memberSince = profile?.memberSince == null
        ? null
        : _formatDate(profile!.memberSince!);

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.waterGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                child: _Avatar(uploadUrl: uploadUrl, authToken: authToken),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (role.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (memberSince != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Pescando desde $memberSince',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  static const String _heroTag = 'profile-avatar';

  final String? uploadUrl;
  final String? authToken;

  const _Avatar({required this.uploadUrl, required this.authToken});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.waterGradient,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 2,
        ),
      ),
    );

    if (uploadUrl == null) {
      return placeholder;
    }

    return Semantics(
      button: true,
      label: 'Abrir foto de perfil',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _AvatarViewer(
              heroTag: _heroTag,
              imageUrl: uploadUrl!,
              authToken: authToken,
            ),
          ),
        ),
        child: ClipOval(
          child: SizedBox(
            width: 88,
            height: 88,
            child: Hero(
              tag: _heroTag,
              child: Image.network(
                uploadUrl!,
                headers: authToken == null
                    ? null
                    : {'Authorization': 'Bearer $authToken'},
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return placeholder;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visualização em tela cheia da foto de perfil, com zoom por gesto.
class _AvatarViewer extends StatelessWidget {
  final String heroTag;
  final String imageUrl;
  final String? authToken;

  const _AvatarViewer({
    required this.heroTag,
    required this.imageUrl,
    required this.authToken,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.network(
                imageUrl,
                headers: authToken == null
                    ? null
                    : {'Authorization': 'Bearer $authToken'},
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final UserProfile? profile;

  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Capturas',
            value: '${profile?.catchCount ?? 0}',
            icon: Icons.set_meal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Espécies',
            value: '${profile?.speciesCount ?? 0}',
            icon: Icons.spa,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: "Corpos d'água",
            value: '${profile?.waterBodyCount ?? 0}',
            icon: Icons.water,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
