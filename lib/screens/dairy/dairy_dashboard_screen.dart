import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../models/dairy/dairy_calendar.dart';
import '../../models/dairy/dairy_metrics.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import 'dairy_module_screen.dart';
import 'milk_editor.dart';

class DairyDashboardScreen extends StatefulWidget {
  const DairyDashboardScreen({super.key});
  @override
  State<DairyDashboardScreen> createState() => _DairyDashboardScreenState();
}

class _DairyDashboardScreenState extends State<DairyDashboardScreen> {
  bool inactive = false;
  DairyPhase? phase;
  late String selectedDay;
  final day = TextEditingController();
  String? error;
  @override
  void initState() {
    super.initState();
    selectedDay =
        DairyCalendar.day(FarmScope.read(context).currentTime.toLocal());
    day.text = selectedDay;
  }

  @override
  void dispose() {
    day.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final s = FarmScope.read(context),
            summary = DairyHerdMilk(s.cattle, s.currentTime,
                calendarDay: selectedDay);
        final rows = s.allCattle.where((c) =>
            c.productionCategory == ProductionCategory.dairy &&
            c.isActive != inactive &&
            (phase == null || c.modules.dairy?.phase == phase));
        return FarmPage(
            title: 'Dairy & pemerahan',
            subtitle:
                'Tanggal kalender $selectedDay · profil individual tetap utama',
            back: true,
            children: [
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        'Volume tercatat ${kgLabel(summary.liters)} L · ditahan ${kgLabel(summary.withheld)} L'),
                    Text(
                        'Di luar masa tahan tercatat ${kgLabel(summary.outsideHold)} L'),
                    Text(
                        '${summary.recordedCows}/${summary.totalCows} profil Dairy betina aktif tercatat · ${summary.completeCows} lengkap · ${summary.partialCows} parsial · ${summary.missingCows} belum dicatat'),
                    const Text(
                        'Statistik seluruh profil Dairy betina aktif pada tanggal pilihan. Volume parsial hanya sesi tercatat; yang belum dicatat bukan nol. Di luar masa tahan bukan jaminan susu aman/dapat dijual.'),
                  ])),
              TextField(
                  key: const ValueKey('dairy-dashboard-day'),
                  controller: day,
                  decoration: const InputDecoration(
                      labelText: 'Tanggal tampilan (YYYY-MM-DD)')),
              TextButton(
                  onPressed: () {
                    try {
                      DairyCalendar.parse(day.text);
                      if (day.text.compareTo(
                              DairyCalendar.day(s.currentTime.toLocal())) >
                          0) {
                        throw const FormatException(
                            'Pilih hari ini atau sebelumnya.');
                      }
                      setState(() {
                        selectedDay = day.text;
                        error = null;
                      });
                    } catch (e) {
                      setState(() =>
                          error = 'Tanggal tidak valid atau di masa depan.');
                    }
                  },
                  child: const Text('Tampilkan tanggal')),
              if (error != null) InfoBanner(error!, warning: true),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: const Text('Aktif'),
                    selected: !inactive,
                    onSelected: (_) => setState(() => inactive = false)),
                ChoiceChip(
                    label: const Text('Nonaktif'),
                    selected: inactive,
                    onSelected: (_) => setState(() => inactive = true))
              ]),
              const Text(
                  'Kelompok fungsional adalah filter fase manual, bukan membership atau sumber data kedua.'),
              Wrap(spacing: 8, runSpacing: 4, children: [
                ChoiceChip(
                    label: const Text('Semua fase'),
                    selected: phase == null,
                    onSelected: (_) => setState(() => phase = null)),
                for (final p in DairyPhase.values)
                  ChoiceChip(
                      label: Text(dairyPhaseLabels[p]!),
                      selected: phase == p,
                      onSelected: (_) => setState(() => phase = p))
              ]),
              if (rows.isEmpty)
                const Text('Tidak ada profil untuk filter ini.'),
              for (final c in rows)
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(c.nameOrId,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      Text(
                          '${dairyPhaseLabels[c.modules.dairy?.phase] ?? 'Fase belum dicatat'} · ${c.status.label}'),
                      Text(DairyMetrics(c, s.currentTime,
                                      calendarDay: selectedDay)
                                  .today ==
                              null
                          ? 'Tanggal ini belum dicatat'
                          : '${kgLabel(DairyMetrics(c, s.currentTime, calendarDay: selectedDay).today!.liters)} L tercatat'),
                      Wrap(spacing: 8, children: [
                        TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        DairyModuleScreen(cattleId: c.id))),
                            child: const Text('Profil Dairy')),
                        FilledButton(
                            key: ValueKey('quick-milk-${c.id}'),
                            onPressed: c.isActive && c.gender == 'Betina'
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) => MilkEditor(
                                            cattle: c,
                                            existing: DairyMetrics(
                                                    c, s.currentTime,
                                                    calendarDay: selectedDay)
                                                .today
                                                ?.record,
                                            initialDay: selectedDay)))
                                : null,
                            child: const Text('Catat / koreksi susu'))
                      ]),
                    ])),
            ]);
      });
}

class DairyHomeSummary extends StatelessWidget {
  const DairyHomeSummary({super.key});
  @override
  Widget build(BuildContext context) {
    final s = FarmScope.read(context), m = s.dairyMilk;
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const DairyDashboardScreen())),
          child: const Text('Ringkasan Dairy & pemerahan')),
      Text(
          'Hari ini ${kgLabel(m.liters)} L tercatat · ${m.recordedCows}/${m.totalCows} profil betina aktif'),
      Text(
          '${m.completeCows} lengkap · ${m.partialCows} parsial · ${m.missingCows} belum dicatat'),
      Text(
          'Ditahan ${kgLabel(m.withheld)} L · di luar masa tahan tercatat ${kgLabel(m.outsideHold)} L'),
      const Text(
          'Volume tercatat, bukan estimasi susu herd. Di luar masa tahan bukan jaminan aman.')
    ]));
  }
}
