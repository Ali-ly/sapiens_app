import 'package:flutter/material.dart';

import '../../models/feed_plan.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../feed/feed_shopping_screen.dart';
import 'group_detail_screen.dart';
import 'group_editor.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key, this.back = true});
  final bool back;
  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  bool archived = false;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final store = FarmScope.read(context);
        final groups = store.groups
            .where((g) => g.archived == archived)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        Future<void> create() async {
          final group = await showGroupEditor(context);
          if (group != null && context.mounted) {
            Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => GroupDetailScreen(groupId: group.id)));
          }
        }

        return FarmPage(
            title: 'Kelompok/kandang',
            subtitle:
                '${store.activeGroups.length} kelompok aktif · ${store.groupHeadCount} ekor pada data kelompok',
            eyebrow: 'KELOMPOK & KANDANG',
            back: widget.back,
            action: IconButton(
                tooltip: 'Buat kelompok/kandang',
                icon: const Icon(Icons.add),
                onPressed: create),
            children: [
              const InfoBanner(
                  'Opsi tambahan untuk ternak banyak. Catat jumlah, bobot rata-rata, dan target kelompok tanpa membuat profil satu per satu.'),
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: const Text('Aktif'),
                    selected: !archived,
                    onSelected: (_) => setState(() => archived = false)),
                ChoiceChip(
                    label: const Text('Arsip'),
                    selected: archived,
                    onSelected: (_) => setState(() => archived = true))
              ]),
              const SizedBox(height: 16),
              if (groups.isEmpty)
                EmptyPanel(
                    title: archived
                        ? 'Belum ada arsip'
                        : 'Mulai dari satu kandang',
                    message:
                        'Buat kelompok dan catat data ternak secara massal, tanpa mendaftarkan sapi satu per satu.',
                    action: archived
                        ? null
                        : FilledButton(
                            onPressed: create,
                            child: const Text('Buat kelompok/kandang'))),
              if (!archived && groups.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const FeedShoppingScreen(
                              initialGroupScope: true))),
                  icon: const Icon(Icons.grass_rounded),
                  label: const Text('Rekap pakan kelompok'),
                ),
                const SizedBox(height: 12),
              ],
              ...groups.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                      padding: 4,
                      child: ListTile(
                        leading: Icon(g.archived
                            ? Icons.archive_outlined
                            : Icons.grid_view_rounded),
                        title: Text(g.name),
                        subtitle: Text(
                            '${g.headCount} ekor · ${g.averageWeightKg == null ? 'bobot rata-rata belum diisi' : '${kgLabel(g.averageWeightKg!)} kg/ekor'}\n${targetLabels[g.target]} · ${g.archived ? 'diarsipkan' : store.groupPlanReady(g) ? 'pakan terkini' : 'pakan belum terkini'}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    GroupDetailScreen(groupId: g.id))),
                      )))),
            ]);
      });
}
