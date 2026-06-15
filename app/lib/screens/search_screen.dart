import 'package:flutter/material.dart';

import '../main.dart';
import '../models/fish.dart';
import '../services/fish_service.dart';

/// Tela de busca de espécies de peixe, alimentada pelo endpoint `/api/fish`.
class SearchScreen extends StatefulWidget {
  /// Serviço injetável (facilita os testes com um cliente HTTP simulado).
  final FishService? service;

  const SearchScreen({super.key, this.service});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final FishService _service;
  final TextEditingController _controller = TextEditingController();

  String _query = '';
  FishType? _typeFilter; // null = todos
  bool _loading = true;
  String? _error;
  List<Fish> _allFish = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FishService();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    // Só fechamos o cliente que nós mesmos criamos.
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fish = await _service.fetchFish();
      if (!mounted) return;
      setState(() {
        _allFish = fish;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<Fish> get _results {
    final q = _query.toLowerCase();
    return _allFish.where((f) {
      final matchesType = _typeFilter == null || f.type == _typeFilter;
      final matchesQuery =
          q.isEmpty ||
          f.name.toLowerCase().contains(q) ||
          (f.region?.toLowerCase().contains(q) ?? false) ||
          f.type.label.toLowerCase().contains(q);
      return matchesType && matchesQuery;
    }).toList();
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
    // Brancos intencionais sobre gradiente de marca.
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
                'Espécies',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Descubra peixes e onde encontrá-los',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Buscar peixe, região ou habitat...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
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
              const SizedBox(height: 12),
              _buildFilters(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final cs = Theme.of(context).colorScheme;
    Widget chip(String label, FishType? type) {
      final selected = _typeFilter == type;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _typeFilter = type),
          backgroundColor: cs.surfaceContainerHigh,
          selectedColor: cs.secondaryContainer,
          surfaceTintColor: Colors.transparent,
          labelStyle: TextStyle(
            color: selected ? cs.onSecondaryContainer : cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(
            color: selected ? Colors.transparent : cs.outlineVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('Todos', null),
          chip(FishType.freshwater.label, FishType.freshwater),
          chip(FishType.saltwater.label, FishType.saltwater),
          chip(FishType.brackish.label, FishType.brackish),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _EmptyState(
        icon: Icons.cloud_off,
        message: _error!,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }

    final results = _results;
    if (results.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off,
        message: 'Nenhum resultado encontrado.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: results.length,
        itemBuilder: (context, index) => _FishCard(
          fish: results[index],
          onTap: () => _showDetails(results[index]),
        ),
      ),
    );
  }

  void _showDetails(Fish fish) {
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
                _FishAvatar(type: fish.type, iconPath: fish.iconPath, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    fish.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.water,
              label: 'Habitat',
              value: fish.type.label,
            ),
            if (fish.region != null && fish.region!.isNotEmpty)
              _DetailRow(
                icon: Icons.place,
                label: 'Região',
                value: fish.region!,
              ),
            if (fish.description != null && fish.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                fish.description!,
                style: TextStyle(height: 1.4, color: cs.onSurface),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card de uma espécie na lista de resultados.
class _FishCard extends StatelessWidget {
  final Fish fish;
  final VoidCallback onTap;

  const _FishCard({required this.fish, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _FishAvatar(type: fish.type, iconPath: fish.iconPath, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fish.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _TypeBadge(type: fish.type),
                        if (fish.region != null && fish.region!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    fish.region!,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cor associada a cada habitat, usada em avatares e badges.
Color _colorForType(FishType type) {
  switch (type) {
    case FishType.freshwater:
      return AppColors.secondary;
    case FishType.saltwater:
      return AppColors.primary;
    case FishType.brackish:
      return AppColors.sand;
  }
}

class _FishAvatar extends StatelessWidget {
  final FishType type;
  final String? iconPath;
  final double size;

  const _FishAvatar({required this.type, this.iconPath, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(type);
    final radius = BorderRadius.circular(14);
    final path = iconPath;

    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: radius,
      ),
      child: Icon(Icons.set_meal, color: color, size: size * 0.55),
    );

    if (path == null || path.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final FishType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(type);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color == AppColors.sand ? cs.onSurface : color,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
