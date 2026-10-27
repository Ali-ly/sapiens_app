import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/cattle.dart';
import '../../domain/condition.dart';
import '../../domain/milk_metrics.dart';
import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import '../../ui/history_chart.dart';
import 'milk_editor_page.dart';

class MilkSection extends ConsumerWidget {
  const MilkSection({super.key, required this.cattle});
  final Cattle cattle;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cattle.sex != Sex.female) {
      return const Notice('Produksi susu hanya untuk sapi perah betina.');
    }
    final m = MilkMetrics(cattle, ref.watch(clockProvider)());
    final lactating =
        (cattle.condition as DairyCondition).stage?.lactating == true;
    final latest = m.latest;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (m.holds.isNotEmpty)
        Notice(
            'Masa tahan susu aktif sampai ${dayText(m.holds.map((e) => e.until!).reduce((a, b) => a.compareTo(b) > 0 ? a : b))}, sesuai tanggal yang dicatat pengguna. Status ini tidak menentukan diagnosis atau durasi obat.',
            warning: true),
      if (!lactating)
        const Notice(
            'Fase saat ini belum laktasi. Histori tetap dapat dibaca dan dikoreksi.'),
      FilledButton.icon(
          onPressed: cattle.active && lactating
              ? () => openPage(context, MilkEditorPage(cattle: cattle))
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Catat produksi susu')),
      const Heading('Produksi tercatat'),
      MetricGrid(children: [
        Metric(
            label: 'Catatan terbaru',
            value: latest == null
                ? 'Belum ada'
                : '${number(latest.recordedAmount)} ${latest.unit.label}',
            detail: latest == null
                ? 'Tidak dianggap nol.'
                : '${dayText(latest.date)} · ${latest.complete ? 'Lengkap' : 'Parsial'}'),
        Metric(
            label: 'Hari laktasi / DIM',
            value: m.dim == null ? 'Belum diketahui' : '${m.dim} hari',
            detail: m.calving == null
                ? 'Perlu tanggal kelahiran aktual.'
                : 'Dari kelahiran ${dayText(m.calving!.date)}')
      ]),
      if (latest != null) ...[
        MetricGrid(children: [
          Metric(
              label: 'Rata-rata 7 hari lengkap',
              value: m.average(latest.unit, 7) == null
                  ? 'Belum ada'
                  : '${number(m.average(latest.unit, 7)!)} ${latest.unit.label}',
              detail: 'Hanya hari lengkap dengan satuan yang sama.'),
          Metric(
              label: 'Rata-rata 30 hari lengkap',
              value: m.average(latest.unit, 30) == null
                  ? 'Belum ada'
                  : '${number(m.average(latest.unit, 30)!)} ${latest.unit.label}',
              detail: 'Hari kosong tidak dianggap nol.')
        ]),
        Surface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.trend(latest.unit) == null
              ? 'Tren belum dapat dihitung.'
              : 'Perubahan dua hari lengkap terakhir: ${number(m.trend(latest.unit)!)} ${latest.unit.label}'),
          const SizedBox(height: 8),
          Text(m.peak(latest.unit) == null
              ? 'Puncak laktasi belum tersedia.'
              : 'Puncak tercatat pada siklus ini: ${number(m.peak(latest.unit)!.recordedAmount)} ${latest.unit.label} · ${dayText(m.peak(latest.unit)!.date)}')
        ])),
        if (m.curve.where((r) => r.unit == latest.unit).length >= 2) ...[
          const Heading('Kurva laktasi tercatat'),
          Surface(
              child: HistoryChart(
                  values: m.curve
                      .where((r) => r.unit == latest.unit)
                      .map((r) => r.recordedAmount)
                      .toList(),
                  description:
                      'Kurva berdasarkan catatan susu lengkap pada siklus kelahiran saat ini.'))
        ],
      ],
      const Heading('Riwayat harian'),
      if (m.days.isEmpty)
        const EmptyMessage(
            title: 'Belum ada produksi susu',
            message:
                'Mulai dari total harian atau satu sesi pemerahan. Tidak perlu menebak sesi yang belum dicatat.'),
      for (final r in m.days.reversed)
        Surface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Row(children: [
                Expanded(
                    child: Text(dayText(r.date),
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                Tag(r.complete ? 'Lengkap' : 'Parsial', warning: !r.complete)
              ]),
              const SizedBox(height: 10),
              Text('${number(r.recordedAmount)} ${r.unit.label}',
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w700)),
              Text(r.mode == MilkMode.totalDaily
                  ? 'Total harian'
                  : 'Pagi: ${r.am == null ? 'Belum dicatat' : number(r.am!)} · Sore: ${r.pm == null ? 'Belum dicatat' : number(r.pm!)}'),
              if (cattle.active)
                TextButton(
                    onPressed: () => openPage(
                        context, MilkEditorPage(cattle: cattle, record: r)),
                    child: const Text('Lengkapi / koreksi'))
            ])),
      if (cattle.milk.isNotEmpty)
        ExpansionTile(title: const Text('Lihat histori koreksi'), children: [
          for (final r in cattle.milk.reversed)
            ListTile(
                title: Text(
                    '${dayText(r.date)} · ${number(r.recordedAmount)} ${r.unit.label}'),
                subtitle: Text(
                    '${r.correctionOf == null ? 'Catatan awal' : 'Koreksi catatan sebelumnya'} · ${dateText(r.createdAt)}'))
        ]),
    ]);
  }
}
