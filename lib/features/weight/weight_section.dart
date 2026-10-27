import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../domain/cattle.dart';
import '../../domain/records.dart';
import '../../ui/components.dart';
import '../../ui/history_chart.dart';
import 'photo_picker.dart';
import 'weight_page.dart';

class WeightSection extends ConsumerWidget {
  const WeightSection({super.key, required this.cattle});
  final Cattle cattle;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = cattle.latestWeight;
    final delta = cattle.weights.length < 2
        ? null
        : latest.kg - cattle.weights[cattle.weights.length - 2].kg;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MetricGrid(children: [
        Metric(
            label: 'Bobot terbaru',
            value: '${number(latest.kg)} kg',
            detail:
                '${dateText(latest.measuredAt)} · ${latest.source == WeightSource.manual ? 'Manual' : 'Estimasi foto'}'),
        Metric(
            label: 'Perubahan dari sebelumnya',
            value: delta == null
                ? 'Belum ada'
                : '${delta >= 0 ? '+' : ''}${number(delta)} kg',
            detail: delta == null
                ? 'Perlu pengukuran berikutnya.'
                : 'Dua catatan bobot terakhir.')
      ]),
      FilledButton.icon(
          onPressed: cattle.active
              ? () => openPage(context, WeightPage(cattle: cattle))
              : null,
          icon: const Icon(Icons.monitor_weight_outlined),
          label: const Text('Cek Berat Lagi')),
      const Heading('Perkembangan bobot'),
      if (cattle.weights.length < 2)
        const Notice('Grafik akan terbentuk setelah pengukuran berikutnya.')
      else
        Surface(
            child: HistoryChart(
                values: cattle.weights.map((w) => w.kg).toList(),
                description:
                    'Grafik ${cattle.weights.length} pengukuran bobot yang benar-benar tercatat.')),
      const Heading('Riwayat pengukuran'),
      for (final w in cattle.weights.reversed)
        Surface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${number(w.kg)} kg',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text(
              '${dateText(w.measuredAt)} · ${w.source == WeightSource.manual ? 'Manual' : 'Estimasi foto'}'),
          if (w.source == WeightSource.photoEstimation)
            Text('${w.photoIds.length} foto valid terkait pengukuran ini.')
        ])),
      Heading('Galeri',
          action: cattle.active
              ? TextButton(
                  onPressed: () async {
                    try {
                      final photos = await ref
                          .read(photoPickerProvider)
                          .pick(camera: false);
                      if (photos.isEmpty) return;
                      await ref
                          .read(farmProvider.notifier)
                          .addPhotos(cattle.id, photos);
                    } catch (e) {
                      if (context.mounted) toast(context, errorText(e));
                    }
                  },
                  child: const Text('Tambah Foto'))
              : null),
      if (cattle.photos.isEmpty)
        const EmptyMessage(
            title: 'Belum ada foto',
            message:
                'Bobot manual tetap tersimpan. Tambahkan foto atau gunakan estimasi foto pada pengukuran berikutnya.')
      else
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final p in cattle.photos)
            Semantics(
                label: p.weightId == null
                    ? 'Foto galeri'
                    : 'Foto pengukuran bobot',
                button: true,
                child: InkWell(
                    onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => Dialog(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  Flexible(
                                      child: Image.memory(p.bytes,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Padding(
                                                  padding: EdgeInsets.all(30),
                                                  child: Text(
                                                      'Foto tidak dapat ditampilkan.')))),
                                  Text(p.weightId == null
                                      ? 'Foto galeri'
                                      : 'Terkait catatan bobot'),
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Tutup'))
                                ]))),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(p.bytes,
                            width: 120,
                            height: 112,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                                width: 120,
                                height: 112,
                                child: Icon(Icons.broken_image_outlined))))))
        ]),
    ]);
  }
}
