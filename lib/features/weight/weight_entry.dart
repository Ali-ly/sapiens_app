import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/contracts.dart';
import '../../application/farm_controller.dart';
import '../../application/providers.dart';
import '../../domain/records.dart';
import '../../ui/components.dart';
import 'photo_picker.dart';

class WeightEntry extends ConsumerStatefulWidget {
  const WeightEntry({super.key, required this.onChanged, this.onEdited});
  final ValueChanged<WeightInput?> onChanged;
  final VoidCallback? onEdited;
  @override
  ConsumerState<WeightEntry> createState() => _WeightEntryState();
}

class _WeightEntryState extends ConsumerState<WeightEntry> {
  WeightSource source = WeightSource.manual;
  final kg = TextEditingController();
  List<UploadPhoto> photos = [];
  WeightEstimate? estimate;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    kg.dispose();
    super.dispose();
  }

  void manualChanged() {
    widget.onEdited?.call();
    final value = numeric(kg.text);
    widget.onChanged(value != null && value.isFinite && value > 0
        ? WeightInput(kg: value)
        : null);
  }

  Future<void> pick(bool camera) async {
    setState(() => busy = true);
    try {
      final selected = await ref.read(photoPickerProvider).pick(camera: camera);
      if (!mounted || selected.isEmpty) return;
      setState(() {
        photos = selected;
        estimate = null;
        error = null;
      });
      widget.onEdited?.call();
      widget.onChanged(null);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> calculate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref.read(gatewayProvider).weight(photos);
      if (!mounted) return;
      setState(() => estimate = result);
      widget.onChanged(WeightInput.estimate(result));
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<WeightSource>(
            segments: const [
              ButtonSegment(
                  value: WeightSource.manual,
                  label: Text('Manual'),
                  icon: Icon(Icons.monitor_weight_outlined)),
              ButtonSegment(
                  value: WeightSource.photoEstimation,
                  label: Text('Estimasi foto'),
                  icon: Icon(Icons.camera_alt_outlined))
            ],
            selected: {
              source
            },
            onSelectionChanged: busy
                ? null
                : (s) {
                    setState(() => source = s.first);
                    if (source == WeightSource.manual) {
                      manualChanged();
                    } else {
                      widget.onChanged(estimate == null
                          ? null
                          : WeightInput.estimate(estimate!));
                    }
                  }),
        const SizedBox(height: 16),
        if (source == WeightSource.manual)
          TextField(
              key: const ValueKey('weight-input'),
              controller: kg,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Bobot (kg)',
                  helperText: 'Masukkan hasil timbangan, lebih dari nol.'),
              onChanged: (_) => manualChanged())
        else ...[
          const Text('Gunakan 1–4 foto sapi. Maksimal 8 MB per foto.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
                onPressed: busy ? null : () => pick(true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Kamera')),
            OutlinedButton.icon(
                onPressed: busy ? null : () => pick(false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeri'))
          ]),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
                height: 136,
                child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => Column(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(photos[i].bytes,
                                  width: 116,
                                  height: 104,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                      width: 116,
                                      height: 104,
                                      child:
                                          Icon(Icons.broken_image_outlined)))),
                          const SizedBox(height: 6),
                          Text(
                              estimate?.rejected.contains(photos[i].name) ==
                                      true
                                  ? 'Foto ${i + 1} tidak dipakai'
                                  : 'Foto ${i + 1}',
                              style: const TextStyle(fontSize: 12)),
                        ]))),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: busy ? null : calculate,
                child: Text(busy ? 'Memeriksa foto…' : 'Estimasi berat'))
          ],
          if (estimate != null) ...[
            const SizedBox(height: 12),
            Surface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${number(estimate!.kg)} kg',
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w700)),
                  Text('${estimate!.accepted.length} foto valid'),
                  if (estimate!.rejected.isNotEmpty)
                    Text(
                        '${estimate!.rejected.length} foto tidak dipakai karena tidak lolos pemeriksaan.'),
                  ExpansionTile(
                      title: const Text('Kualitas estimasi'),
                      children: [
                        if (estimate!.raw['prediction_spread_kg'] != null)
                          Text(
                              'Rentang hasil antarfoto: ${estimate!.raw['prediction_spread_kg']} kg'),
                        const Text(
                            'Estimasi foto bukan hasil timbangan langsung.')
                      ])
                ]))
          ],
        ],
        if (error != null) Notice(error!, warning: true),
      ]);
}
