import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/farm_command_center.dart';
import '../../../models/feed_plan.dart';
import '../../../widgets/farm_ui.dart';

class FarmFeedSummary extends StatelessWidget {
  const FarmFeedSummary(
      {super.key, required this.center, required this.onPrepareFeed});

  final FarmCommandCenter center;
  final VoidCallback onPrepareFeed;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${center.readyCount} dari ${center.cattleCount} sapi memiliki rencana terkini',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: center.feedCoverage,
              minHeight: 7,
              semanticsLabel: 'Cakupan rencana pakan',
              semanticsValue: '${(center.feedCoverage * 100).round()} persen',
              backgroundColor: AppColors.primarySoft,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            Text(
              '${kgLabel(center.dailyFreshKg)} kg pakan segar / hari',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              center.readyCount == 0
                  ? 'Belum ada takaran aktif yang dapat direkap.'
                  : 'Hanya untuk ${center.readyCount} sapi dengan rencana yang masih berlaku.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (center.feedAttentionCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${center.feedAttentionCount} sapi belum tercakup. Total ini belum mewakili kebutuhan seluruh kandang.',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ...center.dailyFeedTotals.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(feedLabels[entry.key] ?? entry.key),
                    ),
                    Text('${kgLabel(entry.value)} kg'),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onPrepareFeed,
              icon: const Icon(CupertinoIcons.bag, size: 18),
              label: const Text('Daftar persiapan pakan'),
            ),
          ],
        ),
      );
}
