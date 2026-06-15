import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/fish.dart';
import '../models/water_body.dart';
import '../services/fish_service.dart';
import 'fish_picker_sheet.dart';

/// Primeira tela do wizard de registro de pesca.
///
/// Nesta iteração ela valida o handoff do mapa e já integra seleção de
/// espécie e fotos, deixando o resto do wizard para o próximo slice.
class CatchFormScreen extends StatefulWidget {
  final LatLng point;
  final WaterBody waterBody;
  final FishService? fishService;

  const CatchFormScreen({
    super.key,
    required this.point,
    required this.waterBody,
    this.fishService,
  });

  @override
  State<CatchFormScreen> createState() => _CatchFormScreenState();
}

class _CatchFormScreenState extends State<CatchFormScreen> {
  final ImagePicker _picker = ImagePicker();
  Fish? _species;
  final List<XFile> _photos = [];

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
    setState(() => _species = fish);
  }

  Future<void> _addPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (!mounted || picked.isEmpty) return;
    setState(() => _photos.addAll(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar pesca')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.waterBody.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.waterBody.waterType.label} • ${widget.waterBody.source ?? 'OSM'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ponto marcado',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(_formatPoint(widget.point)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Espécie',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _species?.name ?? 'Nenhuma espécie selecionada',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _pickSpecies,
                    icon: const Icon(Icons.search),
                    label: const Text('Escolher espécie'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Fotos',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text('${_photos.length}/8'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_photos.isEmpty)
                    const Text('Nenhuma foto adicionada ainda.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _photos
                          .map(
                            (photo) => Chip(
                              avatar: const Icon(Icons.photo, size: 18),
                              label: Text(photo.name),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _addPhotos,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Adicionar fotos'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Próxima etapa',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'O wizard completo entra aqui com detalhes, método e revisão.',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPoint(LatLng value) {
    final lat = value.latitude.toStringAsFixed(5);
    final lon = value.longitude.toStringAsFixed(5);
    return '$lat, $lon';
  }
}
