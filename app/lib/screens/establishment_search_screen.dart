import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/establishment.dart';
import '../services/establishment_service.dart';

/// Tela de busca de estabelecimentos de pesca (lojas, pesqueiros, marinas...),
/// alimentada pelo endpoint `/api/establishments`. O filtro de texto e a
/// categoria são resolvidos pelo backend; a digitação usa debounce para evitar
/// uma requisição por tecla.
class EstablishmentSearchScreen extends StatefulWidget {
  /// Serviço injetável (facilita os testes com um cliente HTTP simulado).
  final EstablishmentService? service;

  /// Chamado ao tocar "Ver no mapa"; o shell abre o mapa centralizado no item.
  final void Function(Establishment establishment)? onShowOnMap;

  const EstablishmentSearchScreen({super.key, this.service, this.onShowOnMap});

  @override
  State<EstablishmentSearchScreen> createState() =>
      _EstablishmentSearchScreenState();
}

class _EstablishmentSearchScreenState extends State<EstablishmentSearchScreen> {
  static const _debounceDuration = Duration(milliseconds: 350);

  late final EstablishmentService _service;
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _query = '';
  EstablishmentCategory? _categoryFilter; // null = todas
  bool _loading = true;
  String? _error;
  List<Establishment> _results = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EstablishmentService();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    // Só fechamos o cliente que nós mesmos criamos.
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _load);
  }

  void _onCategoryChanged(EstablishmentCategory? category) {
    setState(() => _categoryFilter = category);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _service.search(
        q: _query,
        category: _categoryFilter,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
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
                'Locais',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Lojas, pesqueiros, marinas e mais',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por nome...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
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
    Widget chip(String label, EstablishmentCategory? category) {
      final selected = _categoryFilter == category;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => _onCategoryChanged(category),
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
          for (final category in EstablishmentCategory.values)
            chip(category.label, category),
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

    if (_results.isEmpty) {
      return const _EmptyState(
        icon: Icons.store_mall_directory_outlined,
        message: 'Nenhum estabelecimento encontrado.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _results.length,
        itemBuilder: (context, index) => _EstablishmentCard(
          establishment: _results[index],
          onTap: () => _showDetails(_results[index]),
        ),
      ),
    );
  }

  void _showDetails(Establishment establishment) {
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
                _CategoryAvatar(category: establishment.category, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    establishment.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.category_outlined,
              label: 'Categoria',
              value: establishment.category.label,
            ),
            if (establishment.address != null &&
                establishment.address!.isNotEmpty)
              _DetailRow(
                icon: Icons.place_outlined,
                label: 'Endereço',
                value: establishment.address!,
              ),
            if (establishment.phone != null && establishment.phone!.isNotEmpty)
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Telefone',
                value: establishment.phone!,
              ),
            if (establishment.distanceLabel != null)
              _DetailRow(
                icon: Icons.near_me_outlined,
                label: 'Distância',
                value: establishment.distanceLabel!,
              ),
            if (widget.onShowOnMap != null &&
                establishment.location != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onShowOnMap!(establishment);
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver no mapa'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ícone associado a cada categoria de estabelecimento.
IconData _iconForCategory(EstablishmentCategory category) {
  switch (category) {
    case EstablishmentCategory.lojaPesca:
      return Icons.storefront;
    case EstablishmentCategory.pesqueiro:
      return Icons.phishing;
    case EstablishmentCategory.iscaria:
      return Icons.bug_report;
    case EstablishmentCategory.marina:
      return Icons.directions_boat;
    case EstablishmentCategory.rampa:
      return Icons.directions_boat_outlined;
    case EstablishmentCategory.clube:
      return Icons.groups;
    case EstablishmentCategory.outro:
      return Icons.place;
  }
}

/// Card de um estabelecimento na lista de resultados.
class _EstablishmentCard extends StatelessWidget {
  final Establishment establishment;
  final VoidCallback onTap;

  const _EstablishmentCard({required this.establishment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtitle = establishment.address;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CategoryAvatar(category: establishment.category, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      establishment.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _CategoryBadge(category: establishment.category),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
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
                                    subtitle,
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
              if (establishment.distanceLabel != null)
                Text(
                  establishment.distanceLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
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

class _CategoryAvatar extends StatelessWidget {
  final EstablishmentCategory category;
  final double size;

  const _CategoryAvatar({required this.category, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.secondaryContainer;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        _iconForCategory(category),
        color: cs.onSecondaryContainer,
        size: size * 0.55,
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final EstablishmentCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSecondaryContainer,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: cs.onSurface)),
          ),
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
