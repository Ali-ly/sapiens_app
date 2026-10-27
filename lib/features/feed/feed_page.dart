import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/nutrition_context.dart';
import '../../application/providers.dart';
import '../../ui/components.dart';
import '../cattle/add_cattle_page.dart';
import '../cattle/cattle_picker.dart';
import 'catalog_page.dart';
import 'evaluation_page.dart';
import 'result_page.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(farmProvider).requireValue,
        mode = data.account!.mode;
    final rows = data.active.where((c) => c.evaluations.isNotEmpty).toList()
      ..sort((a, b) =>
          b.evaluations.last.createdAt.compareTo(a.evaluations.last.createdAt));
    return PageFrame(
        title: 'Pakan',
        back: false,
        subtitle:
            'Evaluasi dimulai dari satu sapi dan pakan yang sedang diberikan.',
        children: [
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Text('Pahami pakan, sesuai sapimu.',
                    style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.7)),
                const SizedBox(height: 12),
                const Text(
                    'Bobot dan kondisi dibaca dari Profil Sapi. Pilih bahan dari layanan, lalu isi jumlah hariannya.'),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed: () async {
                      if (data.active.isEmpty) {
                        openPage(context, const AddCattlePage());
                        return;
                      }
                      final c = await pickCattle(context);
                      if (c != null && context.mounted) {
                        openPage(context, FeedEvaluationPage(cattleId: c.id));
                      }
                    },
                    icon: const Icon(Icons.grass_outlined),
                    label: Text(data.active.isEmpty
                        ? 'Tambah Sapi'
                        : 'Evaluasi Pakan')),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    onPressed: () => openPage(context, const FeedCatalogPage()),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Daftar Bahan Pakan'))
              ])),
          const Heading('Evaluasi Terbaru'),
          if (rows.isEmpty)
            const EmptyMessage(
                title: 'Belum ada evaluasi',
                message:
                    'Hasil dari backend akan tersimpan sebagai histori per sapi. Tidak ada hasil contoh yang dianggap sebagai data peternakan.'),
          for (final c in rows)
            Surface(
                padding: 8,
                child: ListTile(
                    title: Text(c.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${dateText(c.evaluations.last.createdAt)} · ${backendLabel(c.evaluations.last.response['status']?.toString() ?? 'Tersimpan')}'),
                          const SizedBox(height: 7),
                          Tag(
                              NutritionContext(
                                          mode, c, ref.watch(clockProvider)())
                                      .isCurrent(c.evaluations.last)
                                  ? 'Sesuai konteks tercatat'
                                  : 'Perlu evaluasi ulang',
                              warning: !NutritionContext(
                                      mode, c, ref.watch(clockProvider)())
                                  .isCurrent(c.evaluations.last))
                        ]),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openPage(
                        context,
                        EvaluationResultPage(
                            evaluation: c.evaluations.last,
                            cattleName: c.name)))),
        ]);
  }
}
