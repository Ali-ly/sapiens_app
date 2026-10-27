import 'package:flutter/material.dart';

import '../../../models/feed_plan.dart';
import '../../../models/group_record.dart';
import '../../../widgets/farm_ui.dart';

class GroupRecordTile extends StatelessWidget {
  const GroupRecordTile({super.key, required this.record});

  final GroupRecord record;

  String get _sourceLabel => switch (record.source) {
        'migration' => 'Data awal dari sistem lama',
        'archive' => 'Diarsipkan',
        'restore' => 'Diaktifkan kembali',
        _ => 'Data dicatat',
      };

  @override
  Widget build(BuildContext context) {
    final recordedAt = record.recordedAt.toLocal();
    final time =
        '${recordedAt.hour.toString().padLeft(2, '0')}:${recordedAt.minute.toString().padLeft(2, '0')}';
    final weight = record.averageWeightKg == null
        ? 'bobot belum diisi'
        : '${kgLabel(record.averageWeightKg!)} kg rata-rata';
    final details = [
      '${record.name} · ${targetLabels[record.target]}',
      record.timeBasis == GroupRecordTimeBasis.recorded
          ? '${dateLabel(recordedAt)} $time · $_sourceLabel'
          : '${dateLabel(recordedAt)} · $_sourceLabel (waktu acuan)',
      if (record.notes.isNotEmpty) record.notes,
    ];
    return Panel(
      padding: 6,
      child: ListTile(
        title: Text('${record.headCount} ekor · $weight'),
        subtitle: Text(details.join('\n')),
      ),
    );
  }
}
