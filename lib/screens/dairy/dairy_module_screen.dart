import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/cattle.dart';
import '../../models/dairy/dairy_calendar.dart';
import '../../models/dairy/dairy_metrics.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/livestock_labels.dart';
import '../cattle/cattle_profile_screen.dart';
import '../feed/individual_feed_entry_screen.dart';
import 'dairy_record_editor.dart';
import 'milk_editor.dart';

String dairyRecordReference(DairyExtension d, String id) {
  final r = d.records.where((r) => r.id == id).firstOrNull;
  return r == null
      ? 'Catatan historis terkait tidak tersedia'
      : '${dairyRecordLabels[r.kind]} · ${r.day} · ${r.note}';
}

String milkCorrectionLabel(DairyExtension d, MilkRecord r) {
  if (r.supersedesId == null) return 'Catatan awal';
  final old = d.milk.where((m) => m.id == r.supersedesId).firstOrNull;
  return old == null
      ? 'Koreksi atas snapshot terdahulu'
      : 'Koreksi snapshot ${old.day} yang dicatat ${timestampLabel(old.recordedAt, null)}';
}

String dairyHealthReference(Cattle c, String id) {
  final r = c.core.health.where((r) => r.id == id).firstOrNull;
  return r == null
      ? 'Catatan kesehatan historis tidak tersedia'
      : '${healthKindLabel(r.kind)} · ${timestampLabel(r.occurredAt, r.occurredAtText)} · ${r.note}';
}

enum DairySection { milk, lactation, reproduction, youngstock, feeding, udder }

const dairySectionLabels = {
  DairySection.milk: 'Milk',
  DairySection.lactation: 'Lactation',
  DairySection.reproduction: 'Reproduction',
  DairySection.youngstock: 'Calf / Heifer',
  DairySection.feeding: 'Feeding',
  DairySection.udder: 'Udder / Milk Health'
};

class DairyModuleScreen extends StatefulWidget {
  const DairyModuleScreen(
      {super.key, required this.cattleId, this.initial = DairySection.milk});
  final String cattleId;
  final DairySection initial;
  @override
  State<DairyModuleScreen> createState() => _DairyModuleScreenState();
}

class _DairyModuleScreenState extends State<DairyModuleScreen> {
  late DairySection section;
  String? selectedCycle;
  @override
  void initState() {
    super.initState();
    section = widget.initial;
  }

  void edit(Cattle c, DairyRecordKind kind) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => DairyRecordEditor(cattle: c, kind: kind)));
  void milk(Cattle c, MilkRecord? record) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => MilkEditor(cattle: c, existing: record)));
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final s = FarmScope.read(context), c = s.byId(widget.cattleId);
        if (c == null) {
          return const FarmPage(
              title: 'Profil tidak tersedia',
              subtitle: 'Kembali ke daftar ternak.',
              back: true,
              children: []);
        }
        final d = c.modules.dairy ?? const DairyExtension();
        final validCycle =
            d.calvings.any((r) => r.id == selectedCycle) ? selectedCycle : null;
        final m = DairyMetrics(c, s.currentTime, cycleId: validCycle),
            editable =
                c.isActive && c.productionCategory == ProductionCategory.dairy;
        return FarmPage(
            title: 'Dairy · ${c.nameOrId}',
            subtitle:
                '${dairyPhaseLabels[d.phase] ?? 'Fase belum dicatat'} · ${c.status.label}',
            back: true,
            children: [
              if (d.records.any((r) => r.recordedAt.isAfter(s.currentTime)) ||
                  d.milk.any((r) => r.recordedAt.isAfter(s.currentTime)))
                const InfoBanner(
                    'Catatan dengan waktu pencatatan masa depan tidak masuk ringkasan saat ini. Tinjau waktu perangkat/cadangan.',
                    warning: true),
              if (!editable)
                const InfoBanner(
                    'Histori tetap tersedia. Edit memerlukan profil Dairy aktif.'),
              OutlinedButton(
                  onPressed:
                      editable ? () => edit(c, DairyRecordKind.phase) : null,
                  child: const Text('Catat fase Dairy')),
              Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: dairySectionLabels.entries
                      .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: section == e.key,
                          onSelected: (_) => setState(() => section = e.key)))
                      .toList()),
              if (section == DairySection.milk) ...[
                const SectionHeading('Produksi tercatat'),
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(m.today == null
                          ? 'Hari ini belum dicatat'
                          : 'Hari ini ${kgLabel(m.today!.liters)} L · ${m.today!.record.complete ? 'lengkap' : 'parsial'}'),
                      if (m.latest != null)
                        Text(
                            'Terakhir ${m.latest!.record.day}: ${kgLabel(m.latest!.liters)} L${m.latest!.record.complete ? '' : ' (sesi belum lengkap)'}'),
                      Text(m.average == null
                          ? 'Rata-rata belum tersedia'
                          : 'Rata-rata seluruh histori ${kgLabel(m.average!)} L / hari lengkap tercatat (${m.completeDays.length} hari)'),
                      for (final days in [7, 30])
                        Text(m.averageWindow(days) == null
                            ? 'Rata-rata $days hari belum tersedia (0/$days hari lengkap)'
                            : 'Rata-rata $days hari: ${kgLabel(m.averageWindow(days)!)} L/hari lengkap · ${m.completeWindow(days).length}/$days hari tercatat lengkap'),
                      Text(m.trendDelta == null
                          ? 'Tren perlu dua hari lengkap'
                          : 'Selisih dua hari lengkap terakhir: ${kgLabel(m.trendDelta!)} L · jarak ${m.trendGapDays} hari'),
                      const Text(
                          'Hari/sesi yang tidak dicatat bukan nol dan tidak masuk denominator rata-rata. Angka parsial hanya volume yang sudah dicatat.'),
                      if (m.today != null)
                        Text(
                            'Ditahan ${kgLabel(m.today!.withheldLiters)} L · di luar masa tahan tercatat ${kgLabel(m.today!.outsideHoldLiters)} L'),
                    ])),
                Wrap(spacing: 8, children: [
                  FilledButton(
                      onPressed: editable && c.gender == 'Betina'
                          ? () => milk(c, m.today?.record)
                          : null,
                      child: Text(m.today == null
                          ? 'Catat susu hari ini'
                          : 'Lengkapi / koreksi hari ini')),
                  TextButton(
                      onPressed: editable && c.gender == 'Betina'
                          ? () => milk(c, null)
                          : null,
                      child: const Text('Catat tanggal lain'))
                ]),
                const SectionHeading('Histori harian (snapshot aktif)'),
                for (final day in m.milk.reversed)
                  Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            '${day.record.day} · ${kgLabel(day.liters)} L · ${day.record.complete ? 'lengkap' : 'parsial'}'),
                        Text(day.record.mode == MilkMode.daily
                            ? 'Total harian'
                            : 'AM ${day.record.am == null ? 'belum dicatat' : '${kgLabel(day.record.am!)} L'} · PM ${day.record.pm == null ? 'belum dicatat' : '${kgLabel(day.record.pm!)} L'}'),
                        if (day.withheld)
                          const Text(
                              'Ditahan menurut tanggal pengguna/vet/label.'),
                        if (day.record.qualityNote.isNotEmpty)
                          Text(day.record.qualityNote),
                        TextButton(
                            onPressed:
                                editable ? () => milk(c, day.record) : null,
                            child: const Text('Koreksi snapshot ini')),
                      ])),
                const SectionHeading('Ledger susu (termasuk koreksi)'),
                for (final r in d.milk.reversed)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${r.day} · ${kgLabel(r.recordedLiters)} L'),
                      subtitle: Text(
                          '${r.note}\n${milkCorrectionLabel(d, r)}\nDicatat ${timestampLabel(r.recordedAt, null)}')),
              ],
              if (section == DairySection.lactation) ...[
                const SectionHeading('Siklus dari calving aktual'),
                if (d.calvings.isEmpty)
                  const InfoBanner(
                      'Belum ada calving tercatat. DIM, nomor laktasi, dan kurva siklus belum tersedia; fase tidak membuat calving otomatis.'),
                if (d.calvings.isNotEmpty)
                  DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: validCycle ?? m.cycle?.id,
                      decoration:
                          const InputDecoration(labelText: 'Siklus laktasi'),
                      items: d.calvings
                          .asMap()
                          .entries
                          .map((e) => DropdownMenuItem(
                              value: e.value.id,
                              child: Text(
                                  '${e.value.day} · ${e.value.parity == null ? 'Siklus tercatat ${e.key + 1}' : 'Laktasi ${e.value.parity}'}',
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setState(() => selectedCycle = v)),
                if (m.cycle != null)
                  Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Calving ${m.cycle!.day}'),
                        Text(m.dim == null
                            ? 'Siklus sudah ditutup oleh calving berikutnya'
                            : 'DIM kalender: ${m.dim} (hari calving = 0)'),
                        Text(m.cycle!.parity == null
                            ? 'Paritas belum diketahui; hanya ${m.cycles.indexOf(m.cycle!) + 1} siklus tercatat sampai kelahiran ini.'
                            : 'Nomor laktasi/paritas ${m.cycle!.parity} dari baseline pengguna.'),
                        Text(m.peak == null
                            ? 'Peak belum tersedia dari hari lengkap'
                            : 'Peak teramati ${kgLabel(m.peak!.liters)} L · ${m.peak!.record.day}'),
                        const Text(
                            'DIM memakai selisih tanggal kalender, bukan durasi 24 jam atau jumlah hari pemerahan. Fresh, Early, Dry dan Close-Up dipilih manual dan tetap terpisah.'),
                        MilkCurve(days: m.curve, start: m.cycle!.day),
                        for (final point in m.curve)
                          Text(
                              'DIM ${DairyCalendar.days(m.cycle!.day, point.record.day)} · ${point.record.day} · ${kgLabel(point.liters)} L'),
                      ])),
                FilledButton(
                    onPressed: editable && c.gender == 'Betina'
                        ? () => edit(c, DairyRecordKind.calving)
                        : null,
                    child: const Text('Catat calving aktual')),
              ],
              if (section == DairySection.reproduction) ...[
                const SectionHeading('Reproduksi manual'),
                const InfoBanner(
                    'Hasil pemeriksaan berasal dari pengguna. Days Open/S-C hanya tersedia bila breeding yang berhasil dikonfirmasi eksplisit; tanggal pregnancy check bukan tanggal konsepsi.'),
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          'Days Open ke konsepsi tercatat: ${m.daysOpen == null ? 'belum tersedia' : '${m.daysOpen} hari'}'),
                      Text(
                          'Servis tercatat sampai konsepsi (S/C): ${m.servicesPerConception ?? 'belum tersedia'}'),
                      Text(
                          'Calving Interval: ${m.calvingInterval == null ? 'belum tersedia' : '${m.calvingInterval} hari'}'),
                      const Text(
                          'Berdasarkan catatan yang tersedia; tidak mengklaim histori servis lengkap atau diagnosis fertilitas.')
                    ])),
                Wrap(spacing: 8, children: [
                  for (final k in [
                    DairyRecordKind.service,
                    DairyRecordKind.pregnancy,
                    DairyRecordKind.calving
                  ])
                    TextButton(
                        onPressed: editable && c.gender == 'Betina'
                            ? () => edit(c, k)
                            : null,
                        child: Text(dairyRecordLabels[k]!))
                ]),
              ],
              if (section == DairySection.youngstock) ...[
                const SectionHeading('Pedet & heifer'),
                InfoBanner(
                    '${dairyPhaseLabels[d.phase] ?? 'Fase belum dicatat'} · ${ageEvidenceLabel(c)}'),
                Text(c.estimatedWeight == null
                    ? 'Bobot belum tersedia'
                    : 'Bobot terakhir ${kgLabel(c.estimatedWeight!)} kg'),
                const Text(
                    'Fase tidak mengubah umur atau DOB. Pertumbuhan memakai catatan bobot shared; tidak ada ambang sapih atau breeding otomatis.'),
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => CattleProfileScreen(
                                cattle: c,
                                initialSection: CattleProfileSection.weight))),
                    child: const Text('Bobot & pertumbuhan shared')),
              ],
              if (section == DairySection.feeding) ...[
                const SectionHeading('Feeding Dairy'),
                const InfoBanner(
                    'Evaluasi v2 memakai konteks Twin dan jumlah bahan yang kamu isi. Susu dalam liter tidak diubah menjadi kg; hasil bukan ransum otomatis.',
                    warning: true),
                Text(
                    'Fase ${dairyPhaseLabels[d.phase] ?? 'belum dicatat'} · DIM ${m.dim ?? 'belum tersedia'} · susu terakhir ${m.latest == null ? 'belum tersedia' : '${kgLabel(m.latest!.liters)} L'}'),
                FilledButton(
                    onPressed: c.isActive
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    IndividualFeedEntryScreen(cattleId: c.id)))
                        : null,
                    child: const Text('Evaluasi pakan individual')),
              ],
              if (section == DairySection.udder) ...[
                const SectionHeading('Ambing, susu & masa tahan'),
                InfoBanner(m.heldToday
                    ? 'Ada masa tahan tercatat hari ini. Susu tercatat hari ini dikeluarkan dari volume di luar masa tahan.'
                    : 'Tidak ada masa tahan tercatat yang mencakup hari ini; ini bukan jaminan susu aman.'),
                const Text(
                    'Window tanggal: mulai inklusif, tanggal tinjau kembali eksklusif. Susu pada seluruh tanggal dalam window dipisahkan secara konservatif; tidak ada perkiraan durasi obat.'),
                Wrap(spacing: 8, children: [
                  TextButton(
                      onPressed: editable
                          ? () => edit(c, DairyRecordKind.udder)
                          : null,
                      child: const Text('Catat observasi ambing')),
                  TextButton(
                      onPressed: editable && c.gender == 'Betina'
                          ? () => edit(c, DairyRecordKind.withholding)
                          : null,
                      child: const Text('Catat / koreksi masa tahan'))
                ]),
                for (final r in d.holds)
                  Text('${r.day} sampai sebelum ${r.safeUseDay}: ${r.note}'),
              ],
              const SectionHeading('Histori Dairy'),
              if (d.records.isEmpty) const Text('Belum ada catatan Dairy.'),
              for (final r in d.records.reversed)
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${dairyRecordLabels[r.kind]} · ${r.day}'),
                      if (r.phase != null) Text(dairyPhaseLabels[r.phase]!),
                      if (r.pregnancy != null)
                        Text(pregnancyLabels[r.pregnancy]!),
                      if (r.parity != null) Text('Nomor laktasi ${r.parity}'),
                      Text(r.note),
                      Text(
                          'Dicatat ${timestampLabel(r.recordedAt, null)} · tanggal lokal ${r.recordedOn}'),
                      if (r.calfId != null)
                        Text(
                            'Anak: ${s.byId(r.calfId!)?.nameOrId ?? 'Profil anak historis tidak tersedia'}'),
                      if (r.sireId != null)
                        Text(
                            'Pejantan: ${s.byId(r.sireId!)?.nameOrId ?? 'Profil pejantan historis tidak tersedia'}'),
                      if (r.relatedId != null)
                        Text(
                            'Terkait: ${dairyRecordReference(d, r.relatedId!)}'),
                      if (r.healthRecordId != null)
                        Text(
                            'Kesehatan terkait: ${dairyHealthReference(c, r.healthRecordId!)}'),
                      if (r.safeUseDay != null)
                        Text('Tinjau kembali mulai ${r.safeUseDay}'),
                      if (r.supersedesId != null)
                        Text(
                            'Koreksi: ${dairyRecordReference(d, r.supersedesId!)}')
                    ])),
            ]);
      });
}

class MilkCurve extends StatelessWidget {
  const MilkCurve({super.key, required this.days, required this.start});
  final List<MilkDay> days;
  final String start;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'Kurva observasi: titik = hari lengkap, garis hanya antar tanggal berurutan. Tidak mengisi hari kosong.'),
        if (days.isNotEmpty)
          SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _MilkPainter(days, start)))
      ]);
}

class _MilkPainter extends CustomPainter {
  _MilkPainter(this.days, this.start);
  final List<MilkDay> days;
  final String start;
  @override
  void paint(Canvas canvas, Size size) {
    final maxDay =
            DairyCalendar.days(start, days.last.record.day).clamp(1, 1 << 30),
        maxMilk = days.fold(1.0, (v, d) => d.liters > v ? d.liters : v);
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2;
    Offset? previous;
    String? previousDay;
    for (final d in days) {
      final x = 8 +
              (size.width - 16) *
                  DairyCalendar.days(start, d.record.day) /
                  maxDay,
          y = size.height - 8 - (size.height - 16) * (d.liters / maxMilk);
      final point = Offset(x, y);
      if (previous != null &&
          DairyCalendar.days(previousDay!, d.record.day) == 1) {
        canvas.drawLine(previous, point, paint);
      }
      canvas.drawCircle(point, 3, paint);
      previous = point;
      previousDay = d.record.day;
    }
  }

  @override
  bool shouldRepaint(covariant _MilkPainter old) =>
      old.days != days || old.start != start;
}

class DairyProfilePanel extends StatelessWidget {
  const DairyProfilePanel({super.key, required this.cattle});
  final Cattle cattle;
  @override
  Widget build(BuildContext context) {
    final metrics = DairyMetrics(cattle, FarmScope.read(context).currentTime);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeading('Data ternak perah'),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dairyPhaseLabels[cattle.modules.dairy?.phase] ??
            'Fase Dairy belum dicatat'),
        const SizedBox(height: 10),
        Text(metrics.latest == null
            ? 'Belum ada produksi susu tercatat.'
            : 'Susu terakhir: ${metrics.latest!.liters.toStringAsFixed(1)} liter · ${metrics.latest!.record.day}'),
        Text(metrics.dim == null
            ? 'Laktasi belum memiliki catatan kelahiran.'
            : 'Days in Milk: ${metrics.dim} hari'),
        Wrap(
            spacing: 8,
            children: dairySectionLabels.entries
                .map((e) => TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => DairyModuleScreen(
                                cattleId: cattle.id, initial: e.key))),
                    child: Text(e.value)))
                .toList())
      ]))
    ]);
  }
}
