import 'package:flutter/material.dart';

import '../../models/beef/beef_growth.dart';
import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/livestock_labels.dart';
import '../feed/individual_feed_entry_screen.dart';
import 'beef_record_editor.dart';
import 'feed_stock_screen.dart';

enum BeefSection { growth, feeding, harvest, reproduction }

class BeefModuleScreen extends StatefulWidget {
  const BeefModuleScreen(
      {super.key, required this.cattleId, this.initial = BeefSection.growth});
  final String cattleId;
  final BeefSection initial;
  @override
  State<BeefModuleScreen> createState() => _BeefModuleScreenState();
}

class _BeefModuleScreenState extends State<BeefModuleScreen> {
  late BeefSection section;
  @override
  void initState() {
    super.initState();
    section = widget.initial;
  }

  void edit(Cattle c, BeefRecordKind kind) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => BeefRecordEditor(cattle: c, kind: kind)));
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final store = FarmScope.read(context), c = store.byId(widget.cattleId);
        if (c == null) {
          return const FarmPage(
              title: 'Profil tidak tersedia',
              subtitle: 'Kembali ke daftar ternak.',
              back: true,
              children: []);
        }
        final b = c.modules.beef;
        final editable =
            c.isActive && c.productionCategory == ProductionCategory.beef;
        final growth = BeefGrowth(c, store.currentTime);
        final target = b?.latest(BeefRecordKind.target);
        final visibleSection = section == BeefSection.reproduction &&
                b?.purpose != BeefPurpose.breeding
            ? BeefSection.growth
            : section;
        final sections = {
          BeefSection.growth: 'Growth',
          BeefSection.feeding: 'Feeding',
          BeefSection.harvest: 'Harvest',
          if (b?.purpose == BeefPurpose.breeding)
            BeefSection.reproduction: 'Reproduction'
        };
        return FarmPage(
            title: 'Beef · ${c.nameOrId}',
            subtitle:
                '${beefPurposeLabels[b?.purpose] ?? 'Tujuan belum dipilih'} · ${beefPhaseLabels[b?.phase] ?? 'Fase belum dicatat'}',
            back: true,
            children: [
              if (!editable)
                const InfoBanner(
                    'Histori Beef tetap tersedia. Edit hanya untuk sapi Beef aktif.'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in [
                  BeefRecordKind.purpose,
                  BeefRecordKind.phase,
                  BeefRecordKind.target
                ])
                  OutlinedButton(
                      onPressed: editable ? () => edit(c, k) : null,
                      child: Text(beefRecordLabels[k]!))
              ]),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 8,
                  children: sections.entries
                      .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: visibleSection == e.key,
                          onSelected: (_) => setState(() => section = e.key)))
                      .toList()),
              if (visibleSection == BeefSection.growth) ...[
                const SectionHeading('Pertumbuhan dari catatan bobot'),
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          'Bobot terakhir: ${c.estimatedWeight == null ? 'belum tersedia' : '${kgLabel(c.estimatedWeight!)} kg'}'),
                      if (growth.issue != null) Text(growth.issue!),
                      if (growth.adg != null) ...[
                        Text(
                            'Selisih interval: ${kgLabel(growth.deltaKg!)} kg / ${growth.intervalDays!.toStringAsFixed(2)} hari'),
                        Text(
                            'ADG: ${growth.adg!.toStringAsFixed(3)} kg/hari · ${growth.trend}')
                      ],
                      if (growth.targetKg != null) ...[
                        Text(
                            'Target ${kgLabel(growth.targetKg!)} kg · tersisa ${kgLabel(growth.remainingKg!)} kg'),
                        Text(
                            'Rasio bobot/target: ${(growth.progress! * 100).toStringAsFixed(1)}%')
                      ],
                      if (growth.projectedDays != null)
                        Text(
                            'Proyeksi linier: ${growth.projectedDays!.toStringAsFixed(1)} hari dari bobot terakhir menuju target.'),
                      const Text(
                          'ADG memakai dua catatan terakhir; proyeksi bukan jaminan pertumbuhan. Catatan AI tetap estimasi dan variasinya tidak dimodelkan di sini.'),
                    ])),
                ...c.history.reversed.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${kgLabel(r.weightKg)} kg · ${r.sourceLabel}'),
                    subtitle: Text(timestampLabel(r.date, r.dateText)))),
              ],
              if (visibleSection == BeefSection.feeding) ...[
                const SectionHeading('Rencana pakan Beef'),
                const InfoBanner(
                    'Evaluasi v2 memakai tujuan dari Twin dan jumlah bahan yang kamu isi. Target bobot bukan target ADG; hasil bukan ransum otomatis.'),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: editable && c.estimatedWeight != null
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    IndividualFeedEntryScreen(cattleId: c.id)))
                        : null,
                    child: const Text('Buka kalkulator pakan')),
                if (store.latestPlan(c.id) != null)
                  Text(store.planReady(c)
                      ? 'Rencana terkini tersedia (mode terbatas).'
                      : 'Rencana lama/tertinggal/tidak didukung; tidak masuk kebutuhan stok Beef.'),
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const FeedStockScreen())),
                    child: const Text('Stok & kebutuhan Beef')),
              ],
              if (visibleSection == BeefSection.harvest) ...[
                const SectionHeading('Evaluasi target jual'),
                if (b?.purpose != BeefPurpose.fattening)
                  const InfoBanner(
                      'Evaluasi target jual ini untuk tujuan Penggemukan.'),
                if (store.needsCheck(c))
                  const InfoBanner(
                      'Bobot perlu diperbarui sesuai interval farm. Perbandingan target di bawah adalah data historis, belum kesiapan terkini.',
                      warning: true),
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          harvestLabels[b?.purpose != BeefPurpose.fattening ||
                                  store.needsCheck(c)
                              ? HarvestState.notReady
                              : growth.harvest]!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 22)),
                      Text(growth.currentKg == null
                          ? 'Bobot belum layak untuk evaluasi: ${growth.issue}'
                          : target == null
                              ? 'Tetapkan target pengguna untuk evaluasi.'
                              : 'Bobot ${kgLabel(growth.currentKg!)} kg; target ${kgLabel(target.targetKg!)} kg${target.nearKg == null ? '' : '; batas mendekati ${kgLabel(target.nearKg!)} kg (pilihan pengguna)'}.'),
                      const Text(
                          'Ini perbandingan bobot dengan target pengguna, bukan penilaian kesehatan, harga, atau keputusan jual. Tidak mengubah status ternak secara otomatis.'),
                    ])),
              ],
              if (visibleSection == BeefSection.reproduction) ...[
                const SectionHeading('Catatan reproduksi manual'),
                const InfoBanner(
                    'Catat breeding, pemeriksaan, lalu kelahiran. Hasil pemeriksaan adalah input pengguna; aplikasi tidak mendiagnosis atau memprediksi kebuntingan.'),
                Wrap(spacing: 8, children: [
                  for (final k in [
                    BeefRecordKind.service,
                    BeefRecordKind.pregnancy,
                    BeefRecordKind.calving
                  ])
                    TextButton(
                        onPressed: editable && c.gender == 'Betina'
                            ? () => edit(c, k)
                            : null,
                        child: Text(beefRecordLabels[k]!))
                ]),
                if (c.gender != 'Betina')
                  const Text('Pencatatan induk membutuhkan profil betina.'),
              ],
              const SectionHeading('Histori Beef'),
              if (b == null || b.records.isEmpty)
                const Text('Belum ada catatan Beef.'),
              ...?b?.records.reversed.map((r) => Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            '${beefRecordLabels[r.kind]} · ${beefPurposeLabels[r.purpose] ?? beefPhaseLabels[r.phase] ?? pregnancyLabels[r.pregnancy] ?? ''}'),
                        Text(r.note),
                        Text('Kejadian ${timestampLabel(r.occurredAt, null)}'),
                        Text('Dicatat ${timestampLabel(r.recordedAt, null)}'),
                        if (r.targetKg != null)
                          Text(
                              'Target ${kgLabel(r.targetKg!)} kg${r.nearKg == null ? '' : ' · mendekati ${kgLabel(r.nearKg!)} kg'}'),
                        if (r.relatedId != null)
                          Text('Catatan terkait: ${r.relatedId}'),
                        if (r.sireId != null)
                          Text(
                              'Pejantan: ${store.byId(r.sireId!)?.nameOrId ?? r.sireId}'),
                        if (r.calfId != null)
                          Text(
                              'Anak: ${store.byId(r.calfId!)?.nameOrId ?? r.calfId}')
                      ]))),
            ]);
      });
}

class BeefProfilePanel extends StatelessWidget {
  const BeefProfilePanel({super.key, required this.cattle});
  final Cattle cattle;
  @override
  Widget build(BuildContext context) {
    final growth = BeefGrowth(cattle, FarmScope.read(context).currentTime);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeading('Data ternak pedaging'),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '${beefPurposeLabels[cattle.modules.beef?.purpose] ?? 'Tentukan tujuan Beef'} · ${beefPhaseLabels[cattle.modules.beef?.phase] ?? 'Fase belum dicatat'}'),
        const SizedBox(height: 10),
        Text(growth.targetKg == null
            ? 'Target bobot belum dicatat.'
            : 'Target bobot: ${growth.targetKg!.toStringAsFixed(1)} kg'),
        Text(growth.adg == null
            ? 'ADG belum dapat dihitung dari histori.'
            : 'ADG tercatat: ${growth.adg!.toStringAsFixed(2)} kg/hari'),
        Wrap(spacing: 8, children: [
          for (final e in {
            BeefSection.growth: 'Growth',
            BeefSection.feeding: 'Feeding',
            BeefSection.harvest: 'Harvest',
            if (cattle.modules.beef?.purpose == BeefPurpose.breeding)
              BeefSection.reproduction: 'Reproduction'
          }.entries)
            TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => BeefModuleScreen(
                            cattleId: cattle.id, initial: e.key))),
                child: Text(e.value))
        ])
      ]))
    ]);
  }
}
