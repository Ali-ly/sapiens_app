import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: FarmScope.read(context),
        builder: (context, _) {
          final store = FarmScope.read(context);
          final records = store.cattle
              .expand((c) => c.history.map((r) => (cattle: c, record: r)))
              .toList()
            ..sort((a, b) => b.record.date.compareTo(a.record.date));
          final weighed =
              store.cattle.where((c) => c.estimatedWeight != null).length;
          final average = weighed == 0 ? 0.0 : store.totalWeight / weighed;
          final counts = List.generate(
            7,
            (i) {
              final d = DateTime.now().subtract(Duration(days: 6 - i));
              return records
                  .where((r) => DateUtils.isSameDay(d, r.record.date))
                  .length;
            },
          );
          final peak = counts.fold(1, (a, b) => a > b ? a : b);
          return FarmPage(
            title: 'Perkembangan kandang',
            subtitle: 'Ringkasan berdasarkan catatan peternakanmu.',
            eyebrow: 'INSIGHT & AKTIVITAS',
            back: true,
            children: [
              Row(
                children: [
                  StatTile(
                    '$weighed',
                    'Sapi berbobot',
                    CupertinoIcons.square_stack_3d_up,
                  ),
                  const SizedBox(width: 10),
                  StatTile(
                    kgLabel(average),
                    'Rata-rata kg',
                    CupertinoIcons.chart_bar,
                  )
                ],
              ),
              const SectionHeading('Aktivitas 7 hari'),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${store.checksThisWeek} pencatatan bobot',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 150,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          7,
                          (i) {
                            final d =
                                DateTime.now().subtract(Duration(days: 6 - i));
                            return Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${counts[i]}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Container(
                                    width: 22,
                                    height: counts[i] == 0
                                        ? 4
                                        : counts[i] / peak * 95,
                                    decoration: BoxDecoration(
                                      color: i == 6
                                          ? AppColors.primary
                                          : AppColors.accent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${d.day}/${d.month}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SectionHeading('Kesiapan pakan'),
              Panel(
                child: Row(
                  children: [
                    const Icon(Icons.grass_rounded, color: AppColors.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${store.cattle.where(store.planReady).length} / ${store.cattle.length} sapi dengan rencana pakan terkini',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    )
                  ],
                ),
              ),
              const SectionHeading('Catatan bobot terbaru'),
              if (records.isEmpty)
                const EmptyPanel(
                  title: 'Belum ada aktivitas',
                  message:
                      'Riwayat akan muncul setelah bobot sapi pertama dicatat.',
                )
              else
                ...records.take(30).map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Panel(
                          padding: 15,
                          child: Row(
                            children: [
                              CattleAvatar(cattle: r.cattle, size: 42),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.cattle.nameOrId,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateLabel(r.record.date),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Text(
                                '${kgLabel(r.record.weightKg)} kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          );
        },
      );
}
