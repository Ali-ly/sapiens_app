import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/nutrition_context.dart';
import '../../application/providers.dart';
import '../../domain/cattle.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import 'evaluation_page.dart';
import 'result_page.dart';

class FeedSection extends ConsumerWidget {
  const FeedSection({super.key, required this.cattle, required this.mode});
  final Cattle cattle;
  final FarmMode mode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = cattle.evaluations.lastOrNull;
    final current = latest != null &&
        NutritionContext(mode, cattle, ref.watch(clockProvider)())
            .isCurrent(latest);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (latest == null)
        const EmptyMessage(
            title: 'Belum ada evaluasi pakan',
            message:
                'Evaluasi dimulai dari bobot dan kondisi sapi ini. Pilih bahan dan isi jumlah pakan yang sedang diberikan.')
      else
        Surface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Tag(current ? 'Sesuai konteks tercatat' : 'Perlu evaluasi ulang',
              warning: !current),
          const SizedBox(height: 12),
          Text('Evaluasi terakhir ${dateText(latest.createdAt)}'),
          Text(backendLabel(
              latest.response['status']?.toString() ?? 'Hasil tersimpan')),
          TextButton(
              onPressed: () => openPage(
                  context,
                  EvaluationResultPage(
                      evaluation: latest, cattleName: cattle.name)),
              child: const Text('Lihat Hasil Evaluasi Terbaru'))
        ])),
      FilledButton.icon(
          onPressed: cattle.active
              ? () => openPage(context, FeedEvaluationPage(cattleId: cattle.id))
              : null,
          icon: const Icon(Icons.grass_outlined),
          label:
              Text(latest == null ? 'Evaluasi Pakan' : 'Evaluasi Pakan Lagi')),
      const SizedBox(height: 16),
      const Notice(
          'Perubahan bobot, kondisi, produksi susu, atau konteks laktasi menandai histori lama untuk dievaluasi ulang. Tidak menghitung ulang diam-diam.'),
      if (cattle.evaluations.isNotEmpty) ...[
        const Heading('Riwayat evaluasi'),
        for (final e in cattle.evaluations.reversed)
          Surface(
              padding: 8,
              child: ListTile(
                  title: Text(dateText(e.createdAt)),
                  subtitle: Text(backendLabel(
                      e.response['status']?.toString() ?? 'Tersimpan')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openPage(
                      context,
                      EvaluationResultPage(
                          evaluation: e, cattleName: cattle.name))))
      ],
    ]);
  }
}
