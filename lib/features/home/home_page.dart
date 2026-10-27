import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../application/nutrition_context.dart';
import '../../application/providers.dart';
import '../../domain/condition.dart';
import '../../domain/milk_metrics.dart';
import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import '../cattle/add_cattle_page.dart';
import '../cattle/cattle_picker.dart';
import '../cattle/profile_page.dart';
import '../feed/evaluation_page.dart';
import '../weight/weight_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(farmProvider).requireValue,
        a = data.account!,
        now = ref.watch(clockProvider)();
    final active = data.active.toList();
    final current = active
        .where((c) =>
            c.evaluations.isNotEmpty &&
            NutritionContext(a.mode, c, now).isCurrent(c.evaluations.last))
        .length;
    final lactating = active
        .where((c) =>
            c.sex == Sex.female &&
            c.condition is DairyCondition &&
            (c.condition as DairyCondition).stage?.lactating == true)
        .toList();
    final today = day(now.toLocal());
    final milkToday = active
        .where((c) => c.sex == Sex.female && c.condition is DairyCondition)
        .expand((c) => MilkMetrics(c, now).days.where((m) => m.date == today))
        .toList();
    final units = milkToday.map((m) => m.unit).toSet();
    final actions =
        <({String name, String text, String id, ProfileSection target})>[];
    final activity = <({
      DateTime at,
      String name,
      String label,
      String id,
      ProfileSection target
    })>[];
    for (final c in active) {
      final nc = NutritionContext(a.mode, c, now);
      nc.build();
      final latest = c.evaluations.lastOrNull;
      final partial = a.mode == FarmMode.dairy && c.sex == Sex.female
          ? MilkMetrics(c, now)
              .days
              .where((m) => m.date == today && !m.complete)
              .firstOrNull
          : null;
      if (partial != null) {
        actions.add((
          name: c.name,
          text: 'Lengkapi sesi susu yang belum dicatat',
          id: c.id,
          target: ProfileSection.milk
        ));
      } else if (nc.issues.isNotEmpty && !nc.capabilityLimited) {
        actions.add((
          name: c.name,
          text: 'Lengkapi konteks evaluasi pakan',
          id: c.id,
          target: ProfileSection.care
        ));
      } else if (latest == null && !nc.capabilityLimited) {
        actions.add((
          name: c.name,
          text: 'Mulai evaluasi pakan',
          id: c.id,
          target: ProfileSection.feed
        ));
      } else if (latest != null &&
          !nc.isCurrent(latest) &&
          !nc.capabilityLimited) {
        actions.add((
          name: c.name,
          text: 'Perlu evaluasi ulang setelah perubahan data',
          id: c.id,
          target: ProfileSection.feed
        ));
      }
      for (final w in c.weights) {
        activity.add((
          at: w.measuredAt,
          name: c.name,
          label: 'Bobot ${number(w.kg)} kg dicatat',
          id: c.id,
          target: ProfileSection.weight
        ));
      }
      for (final e in c.evaluations) {
        activity.add((
          at: e.createdAt,
          name: c.name,
          label: 'Evaluasi pakan disimpan',
          id: c.id,
          target: ProfileSection.feed
        ));
      }
      for (final e in c.conditions) {
        activity.add((
          at: e.createdAt,
          name: c.name,
          label: 'Kondisi pemeliharaan dicatat',
          id: c.id,
          target: ProfileSection.care
        ));
      }
      for (final m in c.milk) {
        activity.add((
          at: m.createdAt,
          name: c.name,
          label:
              '${m.correctionOf == null ? 'Produksi susu' : 'Koreksi susu'} ${number(m.recordedAmount)} ${m.unit.label}',
          id: c.id,
          target: ProfileSection.milk
        ));
      }
      for (final e in c.events) {
        activity.add((
          at: e.createdAt,
          name: c.name,
          label: e.kind.label,
          id: c.id,
          target: ProfileSection.care
        ));
      }
    }
    activity.sort((a, b) => b.at.compareTo(a.at));
    return PageFrame(
        maxWidth: AppLayout.contentWidth,
        title: 'Beranda',
        back: false,
        subtitle: '${a.farmName} · ${dateText(now)}',
        children: [
          Surface(
              color: Palette.ink,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        a.owner == 'Peternak'
                            ? 'Selamat datang\ndi SAPIENS.'
                            : 'Halo, ${a.owner}.',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.8,
                            height: 1.15)),
                    const SizedBox(height: 16),
                    Text(a.mode.farmer,
                        style: const TextStyle(
                            color: Palette.leaf,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                        '${active.length} sapi aktif · catatan milik peternakanmu',
                        style: const TextStyle(color: Color(0xFFC5DACF)))
                  ])),
          const Heading('Aksi cepat'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
                onPressed: () => openPage(context, const AddCattlePage()),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Sapi')),
            OutlinedButton.icon(
                onPressed: () async {
                  final c = await pickCattle(context);
                  if (c != null && context.mounted) {
                    openPage(context, WeightPage(cattle: c));
                  }
                },
                icon: const Icon(Icons.monitor_weight_outlined),
                label: const Text('Cek Berat')),
            OutlinedButton.icon(
                onPressed: () async {
                  final c = await pickCattle(context);
                  if (c != null && context.mounted) {
                    openPage(context, FeedEvaluationPage(cattleId: c.id));
                  }
                },
                icon: const Icon(Icons.grass_outlined),
                label: const Text('Evaluasi Pakan'))
          ]),
          const Heading('Peternakan hari ini'),
          MetricGrid(children: [
            Metric(
                label: 'Sapi aktif',
                value: '${active.length}',
                detail: a.mode.label),
            Metric(
                label: 'Evaluasi tersimpan',
                value: '$current / ${active.length}',
                detail:
                    'Masih sesuai konteks tercatat, bukan klaim cukup nutrisi.')
          ]),
          if (a.mode == FarmMode.dairy) ...[
            MetricGrid(children: [
              Metric(
                  label: 'Betina pada fase laktasi',
                  value: '${lactating.length}',
                  detail: 'Dari fase yang dicatat pengguna.'),
              Metric(
                  label: 'Produksi susu hari ini',
                  value: milkToday.isEmpty
                      ? 'Belum dicatat'
                      : units
                          .map((u) =>
                              '${number(milkToday.where((m) => m.unit == u).fold<double>(0, (v, m) => v + m.recordedAmount))} ${u.label}')
                          .join(' + '),
                  detail: milkToday.isEmpty
                      ? 'Hari kosong tidak dianggap nol.'
                      : '${milkToday.where((m) => m.complete).length} lengkap · ${milkToday.where((m) => !m.complete).length} parsial; satuan tidak dikonversi.')
            ]),
          ],
          const Heading('Perlu Perhatian'),
          if (actions.isEmpty)
            Notice(active.isEmpty
                ? 'Mulai dengan menambah sapi dan bobot awalnya.'
                : 'Tidak ada data wajib evaluasi yang perlu dilengkapi pada catatan aktif saat ini. Ini bukan penilaian kesehatan.'),
          for (final row in actions.take(6))
            Surface(
                padding: 8,
                child: ListTile(
                    title: Text(row.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(row.text),
                    leading: const Icon(Icons.edit_note),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openPage(
                        context,
                        CattleProfilePage(
                            cattleId: row.id, initial: row.target)))),
          const Heading('Aktivitas Terbaru'),
          if (activity.isEmpty)
            const EmptyMessage(
                title: 'Belum ada aktivitas',
                message:
                    'Bobot, kondisi, susu, dan evaluasi yang kamu simpan akan muncul di sini.'),
          for (final row in activity.where((e) => !e.at.isAfter(now)).take(8))
            Surface(
                padding: 8,
                child: ListTile(
                    title: Text(row.name),
                    subtitle: Text('${row.label}\n${dateText(row.at)}'),
                    isThreeLine: true,
                    leading: const Icon(Icons.history),
                    onTap: () => openPage(
                        context,
                        CattleProfilePage(
                            cattleId: row.id, initial: row.target)))),
        ]);
  }
}
