import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/contracts.dart';
import '../../application/nutrition_context.dart';
import '../../application/providers.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import '../cattle/profile_page.dart';
import 'catalog_page.dart';
import 'result_page.dart';

class FeedEvaluationPage extends ConsumerStatefulWidget {
  const FeedEvaluationPage({super.key, required this.cattleId});
  final String cattleId;
  @override
  ConsumerState<FeedEvaluationPage> createState() => _FeedEvaluationPageState();
}

class _FeedEvaluationPageState extends ConsumerState<FeedEvaluationPage> {
  final amounts = <String, TextEditingController>{};
  final selected = <String>{};
  String query = '';
  bool dirty = false, saved = false;
  @override
  void dispose() {
    for (final c in amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(farmProvider).requireValue,
        c = data.find(widget.cattleId);
    if (c == null) {
      return const PageFrame(title: 'Sapi tidak tersedia', children: []);
    }
    final mode = data.account!.mode,
        nutrition = NutritionContext(mode, c, ref.watch(clockProvider)());
    final body = nutrition.build();
    final catalog = nutrition.issues.isEmpty
        ? ref.watch(feedCatalogProvider(mode))
        : const AsyncValue<List<FeedIngredient>>.data([]);
    return DraftGuard(
        dirty: dirty && !saved,
        child: PageFrame(
            title: 'Evaluasi Pakan',
            subtitle: '${c.name} · ${mode.label}',
            children: [
              Surface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('${number(c.latestWeight.kg)} kg',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700)),
                    Text(
                        'Bobot terakhir ${dateText(c.latestWeight.measuredAt)}'),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Konteks yang digunakan'),
                        children: [
                          for (final e in body.entries)
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(fieldLabel(e.key)),
                                subtitle: BackendValue(e.value))
                        ])
                  ])),
              if (nutrition.issues.isNotEmpty) ...[
                for (final issue in nutrition.issues)
                  Notice(issue, warning: true),
                OutlinedButton(
                    onPressed: () => openPage(
                        context,
                        CattleProfilePage(
                            cattleId: c.id, initial: ProfileSection.care)),
                    child: Text(nutrition.capabilityLimited
                        ? 'Lihat Perawatan'
                        : 'Lengkapi Perawatan')),
                if (mode == FarmMode.dairy && c.sex == Sex.female)
                  OutlinedButton(
                      onPressed: () => openPage(
                          context,
                          CattleProfilePage(
                              cattleId: c.id, initial: ProfileSection.milk)),
                      child: const Text('Lengkapi Produksi Susu')),
              ] else ...[
                const Heading('Pakan yang sedang diberikan'),
                const Text(
                    'Pilih bahan dari layanan, lalu isi jumlah pakan segar per hari. Takaran ini adalah input evaluasi, bukan rekomendasi otomatis.'),
                const SizedBox(height: 14),
                TextField(
                    decoration: const InputDecoration(
                        labelText: 'Cari bahan pakan',
                        prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setState(() => query = v)),
                const SizedBox(height: 14),
                catalog.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Column(children: [
                          Notice(errorText(e), warning: true),
                          OutlinedButton(
                              onPressed: () =>
                                  ref.invalidate(feedCatalogProvider(mode)),
                              child: const Text('Coba muat lagi'))
                        ]),
                    data: (feeds) {
                      if (feeds.isEmpty) {
                        return const EmptyMessage(
                            title: 'Katalog belum tersedia',
                            message:
                                'Layanan belum mengirim bahan yang valid untuk mode ini. Tidak memakai bahan pengganti lokal.');
                      }
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final f in feeds.where((f) => f.name
                                .toLowerCase()
                                .contains(query.toLowerCase())))
                              Surface(
                                  padding: 12,
                                  child: Column(children: [
                                    CheckboxListTile(
                                        key: ValueKey('feed-${f.id}'),
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(f.name),
                                        subtitle: Text(f.productSpecific
                                            ? 'Data spesifik produk; evaluasi bisa terbatas'
                                            : 'Data referensi layanan'),
                                        value: selected.contains(f.id),
                                        onChanged: (v) => setState(() {
                                              dirty = true;
                                              if (v == true) {
                                                selected.add(f.id);
                                              } else {
                                                selected.remove(f.id);
                                              }
                                            }),
                                        secondary: IconButton(
                                            tooltip: 'Informasi ${f.name}',
                                            icon:
                                                const Icon(Icons.info_outline),
                                            onPressed: () => showModalBottomSheet<
                                                    void>(
                                                context: context,
                                                isScrollControlled: true,
                                                showDragHandle: true,
                                                builder: (_) => SafeArea(
                                                    child: SingleChildScrollView(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(22),
                                                        child: FeedInformation(
                                                            feed: f)))))),
                                    if (selected.contains(f.id))
                                      TextField(
                                          key: ValueKey('amount-${f.id}'),
                                          controller: amounts.putIfAbsent(f.id,
                                              () => TextEditingController()),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                              labelText:
                                                  'Jumlah pakan per hari (kg segar)'),
                                          onChanged: (_) {
                                            if (!dirty) {
                                              setState(() => dirty = true);
                                            }
                                          })
                                  ])),
                            const SizedBox(height: 16),
                            SubmitButton(
                                label: 'Evaluasi & simpan',
                                icon: Icons.analytics_outlined,
                                submit: () async {
                                  final input = selected.map((id) {
                                    final kg = numeric(amounts[id]?.text ?? '');
                                    positive(kg, 'Jumlah pakan');
                                    return FeedAmount(id, kg!);
                                  }).toList();
                                  final e = await ref
                                      .read(farmProvider.notifier)
                                      .evaluate(c.id, input, feeds);
                                  if (!mounted) return;
                                  setState(() => saved = true);
                                  Navigator.of(this.context).pushReplacement(
                                      MaterialPageRoute<void>(
                                          builder: (_) => EvaluationResultPage(
                                              evaluation: e,
                                              cattleName: c.name)));
                                }),
                          ]);
                    }),
              ],
            ]));
  }
}
