import 'package:flutter/material.dart';

import '../../../models/cattle.dart';
import '../../../state/farm_scope.dart';
import '../../../widgets/farm_ui.dart';
import '../../../widgets/livestock_labels.dart';
import '../cattle_health_screen.dart';
import '../cattle_profile_screen.dart';
import '../cattle_record_editor_screen.dart';
import '../cattle_timeline_screen.dart';

class SharedTwinPanel extends StatelessWidget {
  const SharedTwinPanel({super.key, required this.cattle});
  final Cattle cattle;
  void edit(BuildContext context, CattleRecordEdit kind) =>
      Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  CattleRecordEditorScreen(cattle: cattle, kind: kind)));
  @override
  Widget build(BuildContext context) {
    final c = cattle, refs = cattle.core.references;
    final store = FarmScope.read(context);
    Widget parent(String label, String id) {
      final parent = store.byId(id);
      return TextButton(
          onPressed: parent == null
              ? null
              : () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CattleProfileScreen(cattle: parent))),
          child: Text('$label: ${parent?.nameOrId ?? id}'));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeading('Identitas & kesehatan ternak'),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Kategori produksi: ${productionLabel(c.productionCategory)}'),
        if (c.productionCategory == null ||
            store.productionSystems?.singleCategory == null)
          TextButton(
              onPressed: !c.isActive
                  ? null
                  : () => edit(context, CattleRecordEdit.category),
              child: Text(c.productionCategory == null
                  ? 'Klasifikasikan sapi'
                  : 'Ubah kategori')),
        Text('Status ternak: ${c.status.label}'),
        if (c.core.lifecycle.statuses.isNotEmpty)
          Text(
              'Dicatat: ${timestampLabel(c.core.lifecycle.statuses.last.recordedAt, c.core.lifecycle.statuses.last.recordedAtText)}',
              style: const TextStyle(fontSize: 12)),
        TextButton(
            onPressed: () => edit(context, CattleRecordEdit.status),
            child: const Text('Ubah status')),
        Text('Tahap hidup: ${lifeStageLabel(c.core.lifecycle.stage)}'),
        TextButton(
            onPressed: !c.isActive
                ? null
                : () => edit(context, CattleRecordEdit.lifeStage),
            child: const Text('Catat tahap hidup')),
        Text(ageEvidenceLabel(c)),
        if (c.core.identity.ageEvidence.certainty == AgeCertainty.estimated)
          Text(
              'Umur dalam catatan: ${c.ageMonths} bulan. Waktu acuan belum tercatat; nilai ini tidak bertambah otomatis.',
              style: const TextStyle(fontSize: 12)),
        if (c.core.identity.ageEvidence.certainty == AgeCertainty.exact)
          const Text(
              'Tanggal lahir berasal dari data eksplisit, bukan perhitungan dari umur lama.',
              style: TextStyle(fontSize: 12)),
      ])),
      if (refs.damId != null ||
          refs.sireId != null ||
          refs.externalIds.isNotEmpty) ...[
        const SectionHeading('Referensi ternak'),
        Panel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              if (refs.damId != null) parent('Induk betina', refs.damId!),
              if (refs.sireId != null) parent('Induk jantan', refs.sireId!),
              ...refs.externalIds.entries
                  .map((e) => Text('${e.key}: ${e.value}')),
            ])),
      ],
      const SectionHeading('Kesehatan & aktivitas'),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(c.core.health.isEmpty
            ? 'Belum ada catatan kesehatan.'
            : '${c.core.health.length} catatan kesehatan tersimpan.'),
        if (c.core.health.isNotEmpty)
          Text('Terakhir dicatat: ${healthKindLabel(c.core.health.last.kind)}'),
        TextButton(
            onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (_) => CattleHealthScreen(cattleId: c.id))),
            child: const Text('Catatan kesehatan')),
        TextButton(
            onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                    builder: (_) => CattleTimelineScreen(cattleId: c.id))),
            child: const Text('Lihat aktivitas')),
      ])),
    ]);
  }
}
