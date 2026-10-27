import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../domain/condition.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import 'add_cattle_page.dart';
import 'cattle_card.dart';

final cattleQueryProvider = StateProvider<String>((ref) => '');

class CattlePage extends ConsumerStatefulWidget {
  const CattlePage({super.key});
  @override
  ConsumerState<CattlePage> createState() => _CattlePageState();
}

class _CattlePageState extends ConsumerState<CattlePage> {
  bool archived = false;
  BeefPurpose? purpose;
  DairyStage? stage;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(farmProvider).requireValue,
        mode = data.account!.mode,
        query = ref.watch(cattleQueryProvider);
    final rows = data.cattle
        .where((c) =>
            c.active != archived &&
            (c.name.toLowerCase().contains(query.toLowerCase()) ||
                c.userId.toLowerCase().contains(query.toLowerCase())) &&
            (purpose == null ||
                (c.condition is BeefCondition &&
                    (c.condition as BeefCondition).purpose == purpose)) &&
            (stage == null ||
                (c.condition is DairyCondition &&
                    (c.condition as DairyCondition).stage == stage)))
        .toList();
    return PageFrame(
        title: 'Ternak',
        back: false,
        subtitle: '${mode.label} · ${data.active.length} sapi aktif',
        actions: [
          IconButton.filled(
              tooltip: 'Tambah Sapi',
              onPressed: () => openPage(context, const AddCattlePage()),
              icon: const Icon(Icons.add))
        ],
        children: [
          TextFormField(
              initialValue: query,
              decoration: const InputDecoration(
                  labelText: 'Cari Nama / ID sapi',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (v) =>
                  ref.read(cattleQueryProvider.notifier).state = v),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 6, children: [
            ChoiceChip(
                label: const Text('Aktif'),
                selected: !archived,
                onSelected: (_) => setState(() => archived = false)),
            ChoiceChip(
                label: const Text('Arsip'),
                selected: archived,
                onSelected: (_) => setState(() => archived = true)),
            if (mode == FarmMode.beef) ...[
              ChoiceChip(
                  label: const Text('Semua tujuan'),
                  selected: purpose == null,
                  onSelected: (_) => setState(() => purpose = null)),
              for (final p in BeefPurpose.values)
                ChoiceChip(
                    label: Text(p.label),
                    selected: purpose == p,
                    onSelected: (_) =>
                        setState(() => purpose = purpose == p ? null : p))
            ]
          ]),
          if (mode == FarmMode.dairy && data.cattle.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<DairyStage>(
                value: stage,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Filter fase (opsional)'),
                items: [
                  const DropdownMenuItem<DairyStage>(
                      value: null, child: Text('Semua fase')),
                  for (final p in DairyStage.values)
                    DropdownMenuItem(value: p, child: Text(p.label))
                ],
                onChanged: (v) => setState(() => stage = v))
          ],
          const SizedBox(height: 20),
          if (rows.isEmpty)
            EmptyMessage(
                title: data.cattle.isEmpty
                    ? 'Sapi pertama, catatan pertama'
                    : 'Tidak ada sapi pada filter ini',
                message: data.cattle.isEmpty
                    ? 'Tambahkan identitas dan bobot awal. Seluruh perkembangan berikutnya tetap melekat pada sapi yang sama.'
                    : 'Coba ubah pencarian atau filter. Sapi yang diarsipkan tetap menyimpan histori.',
                action: data.cattle.isEmpty
                    ? FilledButton(
                        onPressed: () =>
                            openPage(context, const AddCattlePage()),
                        child: const Text('Tambah Sapi'))
                    : null),
          for (final c in rows)
            CattleCard(cattle: c, mode: mode, now: ref.watch(clockProvider)()),
        ]);
  }
}
