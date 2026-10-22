import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../state/farm_store.dart';
import '../../widgets/farm_ui.dart';
import '../cattle/add_cattle_screen.dart';
import 'feed_calculator_screen.dart';
import 'feed_result_screen.dart';
import 'feed_shopping_screen.dart';

class FeedHubScreen extends StatelessWidget {
  const FeedHubScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmStore.instance,
      builder: (context, _) {
        final store = FarmStore.instance;
        final ready = store.cattle.where(store.planReady).length;
        return FarmPage(
            title: 'Pakan yang tepat.\nSetiap hari.',
            subtitle: 'Dari bobot sapi menjadi takaran pakan yang jelas.',
            eyebrow: 'NUTRISI & RENCANA HARIAN',
            action: IconButton(
                tooltip: 'Daftar kebutuhan pakan',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const FeedShoppingScreen())),
                icon: const Icon(CupertinoIcons.bag)),
            children: [
              Panel(
                  color: AppColors.primaryDark,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const StatusPill('RENCANA PAKAN', dark: true),
                          const Spacer(),
                          const Icon(Icons.grass_rounded,
                              color: AppColors.accent, size: 32)
                        ]),
                        const SizedBox(height: 18),
                        Text('$ready dari ${store.cattle.length} sapi',
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1,
                                color: Colors.white)),
                        const SizedBox(height: 6),
                        const Text('sudah memiliki rencana pakan terkini',
                            style: TextStyle(
                                color: Color(0xFFBBC9B7), fontSize: 13)),
                        const SizedBox(height: 22),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: AppColors.primaryDark),
                                onPressed: store.cattle.isEmpty
                                    ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const AddCattleScreen()))
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const FeedCalculatorScreen())),
                                icon: const Icon(CupertinoIcons.add, size: 18),
                                label: Text(store.cattle.isEmpty
                                    ? 'Tambahkan sapi pertama'
                                    : 'Hitung kebutuhan pakan')))
                      ])),
              const SectionHeading('Rencana per sapi'),
              if (store.cattle.isEmpty)
                const EmptyPanel(
                    title: 'Mulai dari sapimu',
                    message:
                        'Daftarkan sapi dan catat bobotnya. Kami akan memakai bobot tersebut untuk menghitung kebutuhan pakan.'),
              ...store.cattle.map((c) {
                final plan = store.latestPlan(c.id);
                final active = store.planReady(c);
                return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                        child: Column(children: [
                      Row(children: [
                        CattleAvatar(cattle: c, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(c.nameOrId,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 5),
                              Text(
                                  c.estimatedWeight == null
                                      ? 'Belum ada bobot'
                                      : '${kgLabel(c.estimatedWeight!)} kg · ${c.ageMonths} bulan',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary))
                            ])),
                        StatusPill(
                            active
                                ? 'Siap'
                                : plan == null
                                    ? 'Belum dihitung'
                                    : 'Perlu ditinjau',
                            warning: !active)
                      ]),
                      const SizedBox(height: 16),
                      if (plan != null) ...[
                        Row(children: [
                          const Expanded(
                              child: Text('Pakan segar / hari',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary))),
                          Text('${kgLabel(plan.totalFreshKg)} kg',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600))
                        ]),
                        const SizedBox(height: 8),
                        if (!active)
                          const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                  'Bobot perlu dicek atau data sapi telah berubah. Tinjau rencana sebelum digunakan.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warning,
                                      height: 1.5)))
                      ],
                      Row(children: [
                        if (plan != null) ...[
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => FeedResultScreen(
                                              plan: plan, saved: true))),
                                  child: const Text('Lihat rencana'))),
                          const SizedBox(width: 8)
                        ],
                        Expanded(
                            child: FilledButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) => FeedCalculatorScreen(
                                            cattleId: c.id))),
                                child: Text(plan == null
                                    ? 'Hitung pakan'
                                    : 'Hitung ulang')))
                      ])
                    ])));
              }),
              const SectionHeading('Persiapan pakan'),
              Panel(
                  padding: 8,
                  child: ListTile(
                      leading: const Icon(CupertinoIcons.bag,
                          color: AppColors.primary),
                      title: const Text('Kebutuhan seluruh kandang',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Rekap bahan untuk 1, 7, atau 30 hari',
                          style: TextStyle(fontSize: 12)),
                      trailing:
                          const Icon(CupertinoIcons.chevron_right, size: 14),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const FeedShoppingScreen())))),
              const SizedBox(height: 18),
              const InfoBanner(
                  'Rencana ini untuk sapi potong yang tidak bunting dan tidak menyusui. Sesuaikan pemberian dengan kondisi aktual dan arahan tenaga kesehatan hewan.'),
            ]);
      });
}
