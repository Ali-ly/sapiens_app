import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/cattle.dart';
import '../../../models/feed_plan.dart';
import '../../../widgets/farm_ui.dart';
import '../../feed/feed_result_screen.dart';
import '../../feed/individual_feed_entry_screen.dart';

class CattleFeedPanel extends StatelessWidget {
  const CattleFeedPanel(
      {super.key,
      required this.cattle,
      required this.plan,
      required this.active});

  final Cattle cattle;
  final FeedPlan? plan;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    return Panel(
      color: AppColors.primarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.grass_rounded,
                color: AppColors.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan == null
                          ? 'Dari bobot ke pakan'
                          : '${kgLabel(plan.totalFreshKg)} kg / hari',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      plan == null
                          ? 'Evaluasi bahan memakai konteks sapi.'
                          : active
                              ? 'Rencana terkini siap digunakan.'
                              : !cattle.isActive
                                  ? 'Rencana tersimpan untuk ternak nonaktif.'
                                  : 'Perbarui rencana dengan data terbaru.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('cattle-feed-button'),
            style: FilledButton.styleFrom(
                disabledBackgroundColor: AppColors.divider,
                disabledForegroundColor: AppColors.textSecondary),
            onPressed: !cattle.isActive || cattle.estimatedWeight == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            IndividualFeedEntryScreen(cattleId: cattle.id))),
            icon: Icon(
                !cattle.isActive || cattle.estimatedWeight == null
                    ? CupertinoIcons.lock
                    : CupertinoIcons.arrow_right,
                size: 18),
            label: Text(
              plan == null ? 'Hitung kebutuhan pakan' : 'Hitung ulang pakan',
            ),
          ),
          if (cattle.estimatedWeight == null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                  'Catat bobot manual atau gunakan estimasi foto terlebih dahulu.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          if (plan != null)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => FeedResultScreen(plan: plan, saved: true)),
              ),
              child: const Text('Lihat rincian rencana'),
            )
        ],
      ),
    );
  }
}
