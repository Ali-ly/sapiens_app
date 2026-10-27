import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/cattle.dart';
import 'cattle_avatar.dart';
import 'farm_feedback.dart';
import 'livestock_labels.dart';

class CattleTile extends StatelessWidget {
  const CattleTile(
      {super.key,
      required this.cattle,
      required this.onTap,
      required this.feedReady,
      required this.needsWeightCheck});
  final Cattle cattle;
  final VoidCallback onTap;
  final bool feedReady, needsWeightCheck;
  @override
  Widget build(BuildContext context) {
    final ready = feedReady;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CattleAvatar(cattle: cattle),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cattle.nameOrId,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${cattle.gender} · ${productionLabel(cattle.productionCategory)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        !cattle.isActive
                            ? cattle.status.label
                            : ready
                                ? 'Pakan siap'
                                : needsWeightCheck
                                    ? 'Perbarui bobot'
                                    : 'Belum ada rencana pakan',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: ready ? AppColors.primary : AppColors.warning,
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      cattle.estimatedWeight == null
                          ? '—'
                          : kgLabel(cattle.estimatedWeight!),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.8,
                      ),
                    ),
                    const Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    )
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 13,
                  color: AppColors.textSecondary,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
