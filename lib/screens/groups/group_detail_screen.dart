import 'package:flutter/material.dart';

import '../../models/feed_plan.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import 'group_editor.dart';
import 'group_feed_screen.dart';
import 'widgets/group_record_tile.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final store = FarmScope.read(context);
        final group = store.groupById(groupId);
        if (group == null) {
          return const FarmPage(
              title: 'Kelompok tidak tersedia',
              subtitle: 'Data mungkin telah diganti.',
              back: true,
              children: []);
        }
        final plan = store.latestGroupPlan(groupId);
        final ready = store.groupPlanReady(group);
        final plans = store.groupFeedPlans
            .where((p) => p.groupId == groupId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        Future<void> archive() async {
          final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                      title: const Text('Arsipkan kelompok ini?'),
                      content: const Text(
                          'Data dan histori tetap tersimpan. Rencana kelompok tidak akan masuk rekap aktif.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Arsipkan'))
                      ]));
          if (confirmed != true) {
            return;
          }
          try {
            await store.archiveGroup(groupId);
          } catch (e) {
            if (context.mounted) {
              showError(context, e);
            }
          }
        }

        return FarmPage(
            title: group.name,
            subtitle: group.archived
                ? 'Diarsipkan · data tetap tersimpan'
                : 'Kelompok mandiri · profil individual tidak diperlukan',
            eyebrow: 'LIVESTOCK MANAGEMENT',
            back: true,
            action: group.archived
                ? null
                : IconButton(
                    tooltip: 'Edit data kelompok',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showGroupEditor(context, group: group)),
            children: [
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${group.headCount} ekor',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text(group.averageWeightKg == null
                        ? 'Bobot rata-rata belum diisi'
                        : '${kgLabel(group.averageWeightKg!)} kg bobot rata-rata'),
                    Text('Target: ${targetLabels[group.target]}'),
                    if (group.notes.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(group.notes)),
                    const SizedBox(height: 10),
                    Text(
                        'Data terakhir: ${dateLabel(group.current.recordedAt.toLocal())}'),
                  ])),
              const SectionHeading('Kebutuhan pakan kelompok'),
              if (plan != null)
                InfoBanner(
                    ready
                        ? '${kgLabel(plan.totalFreshKg)} kg pakan segar / hari · rencana terkini'
                        : 'Rencana sebelumnya perlu dihitung ulang.',
                    warning: !ready),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: group.canCalculateFeed
                      ? () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  GroupFeedScreen(groupId: groupId)))
                      : null,
                  icon: const Icon(Icons.grass_rounded),
                  label: const Text('Hitung kebutuhan pakan kelompok')),
              if (!group.archived && !group.canCalculateFeed)
                const Text(
                    'Isi jumlah sapi di atas 0 dan bobot rata-rata untuk mengaktifkan perhitungan.'),
              const SectionHeading('Histori perubahan data'),
              ...group.history.reversed.map((record) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GroupRecordTile(record: record))),
              if (plans.isNotEmpty) ...[
                const SectionHeading('Riwayat rencana pakan'),
                ...plans.map((p) => ListTile(
                    title: Text(
                        '${kgLabel(p.totalFreshKg)} kg / hari · ${p.headCount} ekor'),
                    subtitle: Text(
                        '${dateLabel(p.createdAt.toLocal())} · ${targetLabels[p.target]}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => GroupFeedScreen(
                                groupId: groupId, historyPlanId: p.id))))),
              ],
              const SizedBox(height: 18),
              if (group.archived)
                OutlinedButton(
                    onPressed: () async {
                      try {
                        await store.restoreGroup(groupId);
                      } catch (e) {
                        if (context.mounted) {
                          showError(context, e);
                        }
                      }
                    },
                    child: const Text('Aktifkan kembali kelompok'))
              else
                OutlinedButton.icon(
                    onPressed: archive,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Arsipkan kelompok')),
            ]);
      });
}
