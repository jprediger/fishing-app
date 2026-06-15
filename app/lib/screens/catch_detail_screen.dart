import 'package:flutter/material.dart';

import '../models/catch_record.dart';
import '../services/catch_service.dart';
import '../services/fish_service.dart';
import 'catch_form_screen.dart';

class CatchDetailScreen extends StatefulWidget {
  final int? catchId;
  final CatchRecord? initialRecord;
  final CatchService? catchService;
  final FishService? fishService;
  final String? authToken;

  const CatchDetailScreen({
    super.key,
    this.catchId,
    this.initialRecord,
    this.catchService,
    this.fishService,
    this.authToken,
  }) : assert(catchId != null || initialRecord != null);

  @override
  State<CatchDetailScreen> createState() => _CatchDetailScreenState();
}

class _CatchDetailScreenState extends State<CatchDetailScreen> {
  late final CatchService _service;
  Future<CatchRecord>? _future;
  CatchRecord? _record;
  bool _busy = false;

  bool get _ownsRecord => _record?.mine ?? false;

  @override
  void initState() {
    super.initState();
    _service = widget.catchService ?? CatchService();
    _record = widget.initialRecord;
    if (_record == null) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    if (widget.catchService == null) {
      _service.dispose();
    }
    super.dispose();
  }

  Future<CatchRecord> _load() async {
    final id = widget.catchId;
    if (id == null) throw StateError('catchId required when record is absent');
    final record = await _service.fetchById(id);
    _record = record;
    return record;
  }

  Future<void> _reloadAfterEdit(CatchRecord record) async {
    setState(() => _record = record);
  }

  Future<void> _openEdit() async {
    final record = _record;
    if (record == null || !_ownsRecord || _busy) return;

    final result = await Navigator.of(context).push<CatchRecord>(
      MaterialPageRoute(
        builder: (_) => CatchFormScreen.edit(
          record: record,
          catchService: widget.catchService,
          fishService: widget.fishService,
        ),
      ),
    );

    if (result != null && mounted) {
      await _reloadAfterEdit(result);
    }
  }

  Future<void> _delete() async {
    final record = _record;
    if (record == null || !_ownsRecord || _busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir pesca?'),
        content: const Text('Essa ação remove o registro e as fotos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.delete(record.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_record != null) {
      return _buildScaffold(context, _record!);
    }

    return FutureBuilder<CatchRecord>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Registro de pesca')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Falha ao carregar registro.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _buildScaffold(context, snapshot.data!);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, CatchRecord record) {
    final weather = record.weather;
    return Scaffold(
      appBar: AppBar(title: Text(record.species.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildPhotos(record),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.species.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(record.fishingMethod.label)),
                    Chip(label: Text(record.purpose.label)),
                    Chip(label: Text(record.locationVisibility.label)),
                    if (record.mine) const Chip(label: Text('Meu registro')),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Detalhes',
                  child: Column(
                    children: [
                      _DetailLine('Corpo d\'água', record.waterBody.name),
                      _DetailLine(
                        'Local',
                        record.location == null
                            ? 'Local aproximado'
                            : '${record.location!.latitude.toStringAsFixed(5)}, ${record.location!.longitude.toStringAsFixed(5)}',
                      ),
                      _DetailLine('Data', _formatDate(record.caughtAt)),
                      if (record.weightGrams != null)
                        _DetailLine('Peso', '${record.weightGrams} g'),
                      if (record.lengthMm != null)
                        _DetailLine('Comprimento', '${record.lengthMm} mm'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (weather != null)
                  _SectionCard(
                    title: 'Clima',
                    child: Column(
                      children: [
                        if (weather.temperatureC != null)
                          _DetailLine(
                            'Temperatura',
                            '${weather.temperatureC!.toStringAsFixed(1)} °C',
                          ),
                        if (weather.condition != null)
                          _DetailLine('Condição', weather.condition!.label),
                        if (weather.windSpeedKmh != null)
                          _DetailLine(
                            'Vento',
                            '${weather.windSpeedKmh!.toStringAsFixed(1)} km/h',
                          ),
                        if (weather.humidityPct != null)
                          _DetailLine('Umidade', '${weather.humidityPct}%'),
                        if (weather.pressureHpa != null)
                          _DetailLine(
                            'Pressão',
                            '${weather.pressureHpa!.toStringAsFixed(1)} hPa',
                          ),
                      ],
                    ),
                  ),
                if (record.description != null &&
                    record.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Descrição',
                    child: Text(record.description!.trim()),
                  ),
                ],
                if (_ownsRecord) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _openEdit,
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : _delete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Excluir'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotos(CatchRecord record) {
    if (record.photos.isEmpty) {
      return Container(
        height: 220,
        color: Colors.black12,
        child: const Center(child: Icon(Icons.photo, size: 56)),
      );
    }

    return SizedBox(
      height: 280,
      child: PageView.builder(
        itemCount: record.photos.length,
        itemBuilder: (context, index) {
          final photo = record.photos[index];
          return Image.network(
            _service.uploadUrl(photo.filePath),
            fit: BoxFit.cover,
            headers: widget.authToken == null
                ? null
                : {'Authorization': 'Bearer ${widget.authToken}'},
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.black12,
              child: const Center(child: Icon(Icons.broken_image, size: 56)),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
