import 'package:flutter/material.dart';
import '../../domain/cattle.dart';
import '../../domain/condition.dart';
import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import 'condition_page.dart';
import 'dairy_event_page.dart';

String conditionText(Condition c) => switch (c) {
      BeefCondition() => [
          c.purpose.label,
          if (c.purpose == BeefPurpose.fattening && c.phase != null)
            c.phase!.label,
          if (c.pregnancy != null) c.pregnancy!.label,
          if (c.targetAdg != null)
            'Target kenaikan ${number(c.targetAdg!)} kg/hari'
        ].join(' · '),
      DairyCondition() => c.stage?.label ?? 'Sapi perah jantan',
    };

class CareSection extends StatelessWidget {
  const CareSection({super.key, required this.cattle, required this.mode});
  final Cattle cattle;
  final FarmMode mode;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Heading('Kondisi saat ini'),
        Surface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(conditionText(cattle.condition),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('Dicatat ${dateText(cattle.conditions.last.createdAt)}'),
              if (cattle.active) ...[
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () =>
                        openPage(context, ConditionPage(cattle: cattle)),
                    child: const Text('Perbarui kondisi'))
              ]
            ])),
        if (mode == FarmMode.dairy && cattle.sex == Sex.female) ...[
          const Heading('Reproduksi & kesehatan susu'),
          const Notice(
              'Semua kejadian dicatat manual. Aplikasi tidak mendiagnosis kebuntingan atau menentukan masa tahan obat.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final kind in DairyEventKind.values)
              OutlinedButton(
                  onPressed: cattle.active
                      ? () => openPage(
                          context, DairyEventPage(cattle: cattle, kind: kind))
                      : null,
                  child: Text(kind.label))
          ]),
          const Heading('Kejadian tercatat'),
          if (cattle.events.isEmpty)
            const Text('Belum ada kejadian reproduksi atau kesehatan susu.'),
          for (final e in cattle.events.reversed)
            Surface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(e.kind.label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(dayText(e.date)),
                  if (e.pregnancy != null)
                    Text('Pemeriksaan manual: ${e.pregnancy!.label}'),
                  if (e.parity != null) Text('Nomor laktasi: ${e.parity}'),
                  if (e.until != null)
                    Text('Susu ditahan sampai ${dayText(e.until!)} (termasuk)'),
                  if (e.relatedId != null)
                    Text(
                        'Terkait IB: ${dayText(cattle.events.firstWhere((r) => r.id == e.relatedId).date)}'),
                  if (e.note.isNotEmpty) Text(e.note)
                ])),
        ],
        const Heading('Riwayat kondisi'),
        for (final r in cattle.conditions.reversed)
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(conditionText(r.value)),
                const SizedBox(height: 8),
                Text(
                    'Berlaku ${dateText(r.effectiveAt)} · dicatat ${dateText(r.createdAt)}',
                    style: const TextStyle(fontSize: 12))
              ])),
      ]);
}
