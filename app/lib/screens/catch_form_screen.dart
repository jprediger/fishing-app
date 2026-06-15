import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/catch_draft.dart';
import '../models/catch_record.dart';
import '../models/fish.dart';
import '../services/catch_service.dart';
import '../services/fish_service.dart';
import 'fish_picker_sheet.dart';

/// Wizard de registro de pesca.
///
/// Mantém o estado em [CatchDraft] para permitir ida e volta entre passos sem
/// perder seleções locais.
class CatchFormScreen extends StatefulWidget {
  final CatchDraft draft;
  final CatchService? catchService;
  final FishService? fishService;
  final CatchRecord? editingRecord;
  final Future<List<XFile>> Function()? photoPicker;

  const CatchFormScreen({
    super.key,
    required this.draft,
    this.catchService,
    this.fishService,
    this.editingRecord,
    this.photoPicker,
  });

  factory CatchFormScreen.create({
    required CatchDraft draft,
    CatchService? catchService,
    FishService? fishService,
    Future<List<XFile>> Function()? photoPicker,
  }) {
    return CatchFormScreen(
      draft: draft,
      catchService: catchService,
      fishService: fishService,
      photoPicker: photoPicker,
    );
  }

  factory CatchFormScreen.edit({
    required CatchRecord record,
    CatchService? catchService,
    FishService? fishService,
    Future<List<XFile>> Function()? photoPicker,
  }) {
    return CatchFormScreen(
      draft: CatchDraft.fromRecord(record),
      catchService: catchService,
      fishService: fishService,
      editingRecord: record,
      photoPicker: photoPicker,
    );
  }

  @override
  State<CatchFormScreen> createState() => _CatchFormScreenState();
}

class _CatchFormScreenState extends State<CatchFormScreen> {
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final CatchService _service;

  int _step = 0;
  bool _busy = false;
  CatchRecord? _savedRecord;
  List<XFile> _pendingPhotos = const [];
  String? _error;

  bool get _isEditing => widget.editingRecord != null;

  @override
  void initState() {
    super.initState();
    _service = widget.catchService ?? CatchService();
    _weightController.text = widget.draft.weightGrams?.toString() ?? '';
    _lengthController.text = widget.draft.lengthMm?.toString() ?? '';
    _descriptionController.text = widget.draft.description ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _descriptionController.dispose();
    if (widget.catchService == null) _service.dispose();
    super.dispose();
  }

  Future<void> _pickSpecies() async {
    final fish = await showModalBottomSheet<Fish>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: FishPickerSheet(service: widget.fishService),
      ),
    );

    if (!mounted || fish == null) return;
    widget.draft.setSpecies(fish);
  }

  Future<void> _pickPhotos() async {
    final photos = widget.photoPicker != null
        ? await widget.photoPicker!()
        : await _picker.pickMultiImage(imageQuality: 85);

    if (!mounted || photos.isEmpty) return;
    final allowed = 8 - widget.draft.photos.length;
    if (allowed <= 0) return;
    widget.draft.addPhotos(photos.take(allowed));
  }

  Future<void> _save() async {
    if (widget.draft.species == null) {
      setState(() => _error = 'Escolha uma espécie para salvar.');
      return;
    }

    final request = widget.draft.toRequest();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final record = _isEditing
          ? await _service.update(widget.editingRecord!.id, request)
          : await _service.create(request);
      _savedRecord = record;
      _pendingPhotos = List<XFile>.from(widget.draft.photos);

      if (_pendingPhotos.isNotEmpty) {
        await _retryUpload();
        return;
      }

      await _finish(record);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _retryUpload() async {
    final record = _savedRecord;
    if (record == null || _pendingPhotos.isEmpty) return;

    try {
      await _service.uploadPhotos(record.id, _pendingPhotos);
      await _finish(record);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Registro salvo, mas falha ao subir fotos: $e';
      });
    }
  }

  Future<void> _finish(CatchRecord record) async {
    CatchRecord output = record;
    try {
      output = await _service.fetchById(record.id);
    } catch (_) {
      // Fallback: o create/update já tem dados mínimos suficientes.
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _pendingPhotos = const [];
      _error = null;
    });
    Navigator.of(context).pop(output);
  }

  void _next() {
    if (_step == 0 && !widget.draft.canContinueFromStep1) return;
    if (_step < 2) {
      setState(() => _step += 1);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step -= 1);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.draft,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditing ? 'Editar pesca' : 'Registrar pesca'),
          ),
          body: Column(
            children: [
              _StepHeader(step: _step),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _InfoBanner(
                    message: _error!,
                    actionLabel:
                        _savedRecord != null && _pendingPhotos.isNotEmpty
                        ? 'Reenviar fotos'
                        : null,
                    onAction: _savedRecord != null && _pendingPhotos.isNotEmpty
                        ? _retryUpload
                        : null,
                  ),
                ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCaptureStep(context),
                    _buildDetailsStep(context),
                    _buildReviewStep(context),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _back,
                    child: Text(_step == 0 ? 'Cancelar' : 'Voltar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : _step == 2
                        ? _save
                        : _next,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step == 2 ? 'Salvar registro' : 'Continuar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaptureStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SummaryCard(
          title: widget.draft.waterBody.name,
          subtitle:
              '${widget.draft.waterBody.waterType.label} • ${widget.draft.waterBody.source ?? 'OSM'}',
          lines: [
            'Ponto: ${_formatPoint()}',
            'Data: ${_formatDateTime(widget.draft.caughtAt)}',
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Fotos',
          subtitle: 'Até 8 arquivos.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < widget.draft.photos.length; i++)
                    InputChip(
                      avatar: const Icon(Icons.photo, size: 18),
                      label: Text(widget.draft.photos[i].name),
                      onDeleted: () => widget.draft.removePhotoAt(i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _pickPhotos,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Adicionar fotos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Espécie',
          subtitle: 'Seleção vinda do catálogo.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.draft.species?.name ?? 'Nenhuma espécie selecionada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _pickSpecies,
                icon: const Icon(Icons.search),
                label: const Text('Escolher espécie'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SectionCard(
          title: 'Detalhes',
          subtitle: 'Peso, comprimento, método e finalidade.',
          child: Column(
            children: [
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Peso (g)',
                  prefixIcon: Icon(Icons.scale),
                ),
                onChanged: widget.draft.setWeight,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lengthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Comprimento (mm)',
                  prefixIcon: Icon(Icons.straighten),
                ),
                onChanged: widget.draft.setLength,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FishingMethod>(
                initialValue: widget.draft.fishingMethod,
                decoration: const InputDecoration(labelText: 'Método'),
                items: FishingMethod.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) widget.draft.setFishingMethod(value);
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<FishingPurpose>(
                segments: FishingPurpose.values
                    .map(
                      (value) =>
                          ButtonSegment(value: value, label: Text(value.label)),
                    )
                    .toList(),
                selected: {widget.draft.purpose},
                onSelectionChanged: (value) {
                  widget.draft.setPurpose(value.first);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  alignLabelWithHint: true,
                ),
                onChanged: widget.draft.setDescription,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SectionCard(
          title: 'Local e privacidade',
          subtitle: 'O backend aplica a privacidade do ponto.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.draft.waterBody.name),
              Text(_formatPoint()),
              const SizedBox(height: 12),
              SegmentedButton<LocationVisibility>(
                segments: LocationVisibility.values
                    .map(
                      (value) =>
                          ButtonSegment(value: value, label: Text(value.label)),
                    )
                    .toList(),
                selected: {widget.draft.locationVisibility},
                onSelectionChanged: (value) {
                  widget.draft.setLocationVisibility(value.first);
                },
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compartilhar com a comunidade'),
                subtitle: Text(
                  widget.draft.shared
                      ? 'A pesca aparece nos feeds (mapa e posts).'
                      : 'Pesca privada: só você vê.',
                ),
                value: widget.draft.shared,
                onChanged: widget.draft.setShared,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Resumo',
          subtitle: 'Confira antes de salvar.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryLine('Espécie', widget.draft.species?.name ?? '---'),
              _SummaryLine('Fotos', '${widget.draft.photos.length}'),
              _SummaryLine('Método', widget.draft.fishingMethod.label),
              _SummaryLine('Finalidade', widget.draft.purpose.label),
              _SummaryLine(
                'Visibilidade',
                widget.draft.locationVisibility.label,
              ),
              _SummaryLine(
                'Compartilhar',
                widget.draft.shared ? 'Sim' : 'Não (privada)',
              ),
              _SummaryLine(
                'Peso',
                widget.draft.weightGrams?.toString() ?? '---',
              ),
              _SummaryLine(
                'Comprimento',
                widget.draft.lengthMm?.toString() ?? '---',
              ),
              if (widget.draft.description != null &&
                  widget.draft.description!.trim().isNotEmpty)
                _SummaryLine('Descrição', widget.draft.description!.trim()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Clima',
          subtitle: 'Preenchido automaticamente no backend.',
          child: Text(
            'Best-effort: se a API falhar, o registro ainda salva.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  String _formatPoint() {
    final lat = widget.draft.point.latitude.toStringAsFixed(5);
    final lon = widget.draft.point.longitude.toStringAsFixed(5);
    return '$lat, $lon';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _StepHeader extends StatelessWidget {
  final int step;

  const _StepHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const labels = ['Captura', 'Detalhes', 'Revisão'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == step;
          final done = index < step;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                right: index == labels.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primaryContainer
                    : done
                    ? cs.secondaryContainer
                    : cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? cs.primary : cs.outlineVariant,
                ),
              ),
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? cs.onPrimaryContainer
                      : done
                      ? cs.onSecondaryContainer
                      : cs.onSurface,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> lines;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine(this.label, this.value);

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

class _InfoBanner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InfoBanner({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.tertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
