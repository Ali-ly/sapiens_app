import 'package:flutter/material.dart';

import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import 'widgets/farm_action_tile.dart';

class FarmActionsScreen extends StatefulWidget {
  const FarmActionsScreen({super.key});
  @override
  State<FarmActionsScreen> createState() => _FarmActionsScreenState();
}

class _FarmActionsScreenState extends State<FarmActionsScreen> {
  String filter = 'Semua';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: FarmScope.read(context),
        builder: (context, _) {
          final center = FarmScope.read(context).commandCenter;
          final actions = center.actions
              .where(
                (a) =>
                    filter == 'Semua' ||
                    (filter == 'Bobot' ? a.needsWeight : !a.needsWeight),
              )
              .toList();
          return FarmPage(
            title: 'Langkah berikutnya.',
            subtitle:
                'Satu tindakan prioritas per sapi. Daftar diperbarui saat data berubah.',
            eyebrow: 'FARM COMMAND CENTER · TINDAKAN',
            back: true,
            children: [
              Wrap(
                spacing: 8,
                children: ['Semua', 'Bobot', 'Pakan']
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: filter == value,
                        onSelected: (_) => setState(() => filter = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              if (actions.isEmpty)
                const EmptyPanel(
                  title: 'Tidak ada tindakan pada kategori ini',
                  message:
                      'Daftar ini mengikuti kelengkapan bobot dan rencana pakan, bukan pemeriksaan kesehatan sapi.',
                ),
              ...actions.map((action) => FarmActionTile(action: action)),
            ],
          );
        },
      );
}
