import 'package:flutter/material.dart';

import '../models/fish.dart';
import '../services/api_exception.dart';
import '../services/fish_service.dart';

/// Bottom sheet reutilizável para selecionar uma espécie do catálogo.
class FishPickerSheet extends StatefulWidget {
  final FishService? service;

  const FishPickerSheet({super.key, this.service});

  @override
  State<FishPickerSheet> createState() => _FishPickerSheetState();
}

class _FishPickerSheetState extends State<FishPickerSheet> {
  late final FishService _service;
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  String? _error;
  String _query = '';
  FishType? _typeFilter;
  List<Fish> _fish = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FishService();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.service == null) {
      _service.dispose();
    }
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
        _fish = fish;
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
    return _fish.where((fish) {
      final matchesType = _typeFilter == null || fish.type == _typeFilter;
      final matchesQuery = q.isEmpty ||
          fish.name.toLowerCase().contains(q) ||
          (fish.region?.toLowerCase().contains(q) ?? false) ||
          fish.type.label.toLowerCase().contains(q);
      return matchesType && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Escolher espécie',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('Todos', null),
                  _chip(FishType.freshwater.label, FishType.freshwater),
                  _chip(FishType.saltwater.label, FishType.saltwater),
                  _chip(FishType.brackish.label, FishType.brackish),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, FishType? type) {
    final selected = _typeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _typeFilter = type),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _EmptyState(
        message: _error!,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }

    final results = _results;
    if (results.isEmpty) {
      return const _EmptyState(message: 'Nenhuma espécie encontrada.');
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final fish = results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.set_meal),
          ),
          title: Text(fish.name),
          subtitle: Text([
            fish.type.label,
            if (fish.region != null && fish.region!.isNotEmpty) fish.region!,
          ].join(' • ')),
          onTap: () => Navigator.of(context).pop(fish),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
