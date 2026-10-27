import 'package:flutter/material.dart';
import '../../application/nutrition_context.dart';
import '../../domain/cattle.dart';
import '../../domain/condition.dart';
import '../../domain/milk_metrics.dart';
import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import '../care/care_section.dart';
import 'profile_page.dart' show ProfileSection;

class BeefOverview extends StatelessWidget {
  const BeefOverview(
      {super.key, required this.cattle, required this.now, required this.go});
  final Cattle cattle;
  final DateTime now;
  final ValueChanged<ProfileSection> go;
  @override
  Widget build(BuildContext context) {
    final c = cattle.condition as BeefCondition,
        latest = cattle.evaluations.lastOrNull;
    final delta = cattle.weights.length < 2
        ? null
        : cattle.latestWeight.kg - cattle.weights[cattle.weights.length - 2].kg;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Heading('Ringkasan Sapi Potong'),
      MetricGrid(children: [
        Metric(
            label: 'Bobot terbaru',
            value: '${number(cattle.latestWeight.kg)} kg',
            detail: delta == null
                ? 'Pengukuran awal.'
                : 'Perubahan ${delta >= 0 ? '+' : ''}${number(delta)} kg',
            onTap: () => go(ProfileSection.weight)),
        Metric(
            label: 'Pemeliharaan',
            textValue: true,
            value: c.purpose.label,
            detail: c.phase?.label ?? c.pregnancy?.label,
            onTap: () => go(ProfileSection.care))
      ]),
      Surface(
          onTap: () => go(ProfileSection.feed),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pakan', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(latest == null
                ? 'Belum ada evaluasi'
                : NutritionContext(FarmMode.beef, cattle, now).isCurrent(latest)
                    ? 'Evaluasi sesuai konteks tercatat'
                    : 'Perlu evaluasi ulang'),
            const SizedBox(height: 8),
            const Text('Buka evaluasi dari profil sapi ini.')
          ])),
      if (c.targetAdg == null && c.purpose == BeefPurpose.fattening)
        const Notice(
            'Target kenaikan berat per hari belum dicatat. Isi di Perawatan sebelum evaluasi pakan.'),
      OutlinedButton(
          onPressed: () => go(ProfileSection.care),
          child: const Text('Lihat Perawatan')),
    ]);
  }
}

class DairyOverview extends StatelessWidget {
  const DairyOverview(
      {super.key, required this.cattle, required this.now, required this.go});
  final Cattle cattle;
  final DateTime now;
  final ValueChanged<ProfileSection> go;
  @override
  Widget build(BuildContext context) {
    final c = cattle.condition as DairyCondition,
        m = MilkMetrics(cattle, now),
        latest = cattle.evaluations.lastOrNull;
    if (cattle.sex == Sex.male) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Heading('Ringkasan Sapi Perah Jantan'),
        Metric(
            label: 'Bobot terbaru',
            value: '${number(cattle.latestWeight.kg)} kg',
            onTap: () => go(ProfileSection.weight)),
        const Notice(
            'Profil jantan tidak menampilkan fase laktasi, produksi susu, atau reproduksi betina.'),
        OutlinedButton(
            onPressed: () => go(ProfileSection.weight),
            child: const Text('Pantau bobot'))
      ]);
    }
    final pregnancy = m.latestPregnancyCheck;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Heading('Ringkasan Sapi Perah'),
      if (m.holds.isNotEmpty)
        const Notice(
            'Masa tahan susu sedang aktif berdasarkan tanggal yang kamu catat.',
            warning: true),
      MetricGrid(children: [
        Metric(
            label: 'Produksi susu terakhir',
            value: m.latest == null
                ? 'Belum dicatat'
                : '${number(m.latest!.recordedAmount)} ${m.latest!.unit.label}',
            detail: m.latest == null
                ? 'Tidak dianggap nol.'
                : '${dayText(m.latest!.date)} · ${m.latest!.complete ? 'Lengkap' : 'Parsial'}',
            onTap: () => go(ProfileSection.milk)),
        Metric(
            label: 'Fase fisiologis',
            textValue: true,
            value: c.stage?.label ?? 'Belum dipilih',
            detail:
                m.dim == null ? 'DIM belum diketahui.' : 'DIM ${m.dim} hari',
            onTap: () => go(ProfileSection.care)),
        Metric(
            label: 'Bobot terbaru',
            value: '${number(cattle.latestWeight.kg)} kg',
            detail: dateText(cattle.latestWeight.measuredAt),
            onTap: () => go(ProfileSection.weight)),
        Metric(
            label: 'Nomor laktasi',
            value: m.parity?.toString() ?? 'Belum diketahui',
            detail: pregnancy?.pregnancy?.label ??
                'Pemeriksaan kebuntingan belum dicatat.',
            onTap: () => go(ProfileSection.care))
      ]),
      Surface(
          onTap: () => go(ProfileSection.feed),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Evaluasi pakan',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(latest == null
                ? 'Belum ada evaluasi'
                : NutritionContext(FarmMode.dairy, cattle, now)
                        .isCurrent(latest)
                    ? 'Sesuai konteks tercatat'
                    : 'Perlu evaluasi ulang'),
            const SizedBox(height: 8),
            Text(conditionText(cattle.condition))
          ])),
    ]);
  }
}
