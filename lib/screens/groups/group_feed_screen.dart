import 'package:flutter/material.dart';

import '../../models/feed_plan.dart';
import '../../models/group_feed_plan.dart';
import '../../models/livestock_group.dart';
import '../../services/group_feed_service.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';

typedef GroupFeedCalculation = Future<GroupFeedPlan> Function(
    {required LivestockGroup group, required List<String> availableFeeds});

class GroupFeedScreen extends StatefulWidget {
  const GroupFeedScreen(
      {super.key, required this.groupId, this.historyPlanId, this.calculate});
  final String groupId;
  final String? historyPlanId;
  final GroupFeedCalculation? calculate;
  @override
  State<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends State<GroupFeedScreen> {
  late Set<String> feeds;
  GroupFeedPlan? draft;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    feeds = FarmScope.read(context)
            .latestGroupPlan(widget.groupId)
            ?.availableFeeds
            .toSet() ??
        {'rumput'};
  }

  Future<void> calculate() async {
    final store = FarmScope.read(context);
    final group = store.groupById(widget.groupId);
    if (group == null || !group.canCalculateFeed) {
      return;
    }
    if (!feeds.contains('rumput') && !feeds.contains('jerami')) {
      setState(() => error = 'Pilih rumput atau jerami sebagai sumber serat.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await (widget.calculate ?? GroupFeedService.calculate)(
          group: group, availableFeeds: feeds.toList());
      final latest = store.groupById(group.id);
      if (latest == null || !result.matches(latest)) {
        throw StateError(
            'Data kelompok berubah selama perhitungan. Hitung ulang.');
      }
      if (mounted) {
        setState(() => draft = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    if (draft == null) {
      return;
    }
    final store = FarmScope.read(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await store.saveGroupPlan(draft!);
      if (mounted) {
        setState(() => draft = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AnimatedBuilder(
          animation: FarmScope.read(context),
          builder: (context, _) {
            final store = FarmScope.read(context);
            final group = store.groupById(widget.groupId);
            if (group == null) {
              return const FarmPage(
                  title: 'Kelompok tidak tersedia',
                  subtitle: 'Data mungkin telah diganti.',
                  back: true,
                  children: []);
            }
            final history = widget.historyPlanId != null;
            GroupFeedPlan? plan = draft ?? store.latestGroupPlan(group.id);
            if (history) {
              final matches = store.groupFeedPlans.where(
                  (p) => p.id == widget.historyPlanId && p.groupId == group.id);
              plan = matches.isEmpty ? null : matches.first;
            }
            final stale = plan != null && !plan.matches(group);
            return FarmPage(
                title: history ? 'Riwayat pakan kelompok' : 'Pakan kelompok',
                subtitle: group.name,
                back: true,
                children: [
                  InfoBanner(
                      '${group.headCount} ekor · ${group.averageWeightKg == null ? 'bobot rata-rata belum diisi' : '${kgLabel(group.averageWeightKg!)} kg/ekor'} · ${targetLabels[group.target]}'),
                  const SizedBox(height: 14),
                  const InfoBanner(
                      'Estimasi untuk kelompok yang relatif seragam: API memakai bobot rata-rata, lalu takaran per ekor dikalikan jumlah sapi. Ini bukan penjumlahan profil individual.'),
                  if (!history) ...[
                    const SectionHeading('Bahan tersedia'),
                    ...feedLabels.entries.map((entry) => CheckboxListTile(
                        title: Text(entry.value),
                        value: feeds.contains(entry.key),
                        onChanged: busy
                            ? null
                            : (value) => setState(() {
                                  if (value == true) {
                                    feeds.add(entry.key);
                                  } else {
                                    feeds.remove(entry.key);
                                  }
                                }))),
                    FilledButton(
                        onPressed:
                            busy || !group.canCalculateFeed ? null : calculate,
                        child: Text(
                            busy ? 'Memproses…' : 'Hitung pakan kelompok')),
                    if (!group.canCalculateFeed)
                      const Text(
                          'Isi jumlah sapi dan bobot rata-rata pada data kelompok terlebih dahulu.'),
                  ],
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: InfoBanner(error!, warning: true)),
                  if (plan != null) ...[
                    const SectionHeading('Hasil estimasi'),
                    if (stale)
                      const InfoBanner(
                          'Data kelompok sudah berubah atau kelompok diarsipkan. Rencana ini tidak masuk rekap terkini.',
                          warning: true),
                    Panel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('${kgLabel(plan.totalFreshKg)} kg / hari',
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(
                              '${kgLabel(plan.freshKgPerHead)} kg/ekor/hari × ${plan.headCount} ekor'),
                          Text(
                              'Bobot rata-rata perhitungan: ${kgLabel(plan.averageWeightKg)} kg · ${targetLabels[plan.target]}'),
                          const SizedBox(height: 14),
                          ...plan.groupPortions.map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                  '${p.label}: ${kgLabel(p.asFedKg)} kg / kelompok / hari'))),
                          if (plan.totalDryMatterKg != null)
                            Text(
                                'Bahan kering: ${kgLabel(plan.totalDryMatterKg! * plan.headCount)} kg / kelompok / hari'),
                          if (plan.warning != null) Text(plan.warning!),
                          ...plan.notes.map(Text.new),
                          const SizedBox(height: 12),
                          Text(
                              'Dihitung ${dateLabel(plan.createdAt.toLocal())}'),
                        ])),
                    const SizedBox(height: 14),
                    if (!history && draft != null)
                      FilledButton(
                          onPressed: busy || stale ? null : save,
                          child: const Text('Simpan rencana kelompok'))
                    else
                      const StatusPill('RENCANA TERSIMPAN'),
                  ] else if (history)
                    const InfoBanner('Rencana tidak tersedia.'),
                ]);
          }));
}
