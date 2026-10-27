import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/livestock_labels.dart';

T? findRecord<T>(Iterable<T> records, bool Function(T) matches) {
  for (final record in records) {
    if (matches(record)) return record;
  }
  return null;
}

String eventTitle(Cattle c, TwinEvent e) => switch (e.kind) {
      TwinEventKind.weightRecorded => 'Bobot dicatat',
      TwinEventKind.photosAdded => 'Foto ditambahkan',
      TwinEventKind.statusChanged =>
        'Status: ${findRecord(c.core.lifecycle.statuses, (r) => r.id == e.recordId)?.status.label ?? 'Catatan status'}',
      TwinEventKind.lifeStageChanged =>
        'Tahap hidup: ${lifeStageLabel(findRecord(c.core.lifecycle.stages, (r) => r.id == e.recordId)?.stage)}',
      TwinEventKind.healthRecorded => healthKindLabel(
          findRecord(c.core.health, (r) => r.id == e.recordId)!.kind),
      TwinEventKind.productionCategoryChanged =>
        'Kategori: ${productionLabel(e.previousCategory)} → ${productionLabel(e.productionCategory)}',
    };
String eventDetails(Cattle c, TwinEvent e) {
  switch (e.kind) {
    case TwinEventKind.weightRecorded:
      final r = findRecord(c.history, (r) => r.id == e.recordId);
      return r == null ? '' : '${kgLabel(r.weightKg)} kg · ${r.sourceLabel}';
    case TwinEventKind.photosAdded:
      return 'Waktu ini adalah waktu pencatatan, bukan waktu pengambilan foto.';
    case TwinEventKind.statusChanged:
      return findRecord(c.core.lifecycle.statuses, (r) => r.id == e.recordId)
              ?.note ??
          '';
    case TwinEventKind.lifeStageChanged:
      return findRecord(c.core.lifecycle.stages, (r) => r.id == e.recordId)
              ?.note ??
          '';
    case TwinEventKind.healthRecorded:
      final r = findRecord(c.core.health, (r) => r.id == e.recordId);
      return r == null
          ? ''
          : '${r.note}\nKejadian: ${timestampLabel(r.occurredAt, r.occurredAtText)}';
    case TwinEventKind.productionCategoryChanged:
      return e.note;
  }
}

class CattleTimelineScreen extends StatelessWidget {
  const CattleTimelineScreen({super.key, required this.cattleId});
  final String cattleId;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final c = FarmScope.read(context).byId(cattleId);
        if (c == null) {
          return const FarmPage(
              title: 'Profil tidak tersedia',
              subtitle: 'Kembali ke daftar ternak.',
              back: true,
              children: []);
        }
        final events = c.core.timeline.asMap().entries.toList()
          ..sort((a, b) {
            final time = b.value.recordedAt.compareTo(a.value.recordedAt);
            return time == 0 ? b.key.compareTo(a.key) : time;
          });
        return FarmPage(
            title: 'Aktivitas ternak',
            subtitle:
                '${c.nameOrId} · urut waktu pencatatan, terbaru lebih dahulu',
            back: true,
            children: [
              if (events.isEmpty)
                const EmptyPanel(
                    title: 'Belum ada peristiwa tercatat',
                    message:
                        'Bobot dan foto lama tetap tersedia di profil; histori tersebut tidak diubah menjadi event buatan.'),
              ...events.map((row) {
                final e = row.value;
                final details = eventDetails(c, e);
                return Padding(
                    key: ValueKey('timeline-${e.id}'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(eventTitle(c, e),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                              'Dicatat: ${timestampLabel(e.recordedAt, e.recordedAtText)}',
                              style: const TextStyle(fontSize: 12)),
                          if (details.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(details)),
                        ])));
              }),
            ]);
      });
}
