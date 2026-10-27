import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/cattle.dart';
import '../../../models/farm_command_center.dart';
import '../../../widgets/farm_ui.dart';
import '../../beef/beef_module_screen.dart';
import '../../cattle/cattle_profile_screen.dart';
import '../../dairy/dairy_module_screen.dart';
import '../../feed/individual_feed_entry_screen.dart';

class FarmActionTile extends StatelessWidget {
  const FarmActionTile({super.key, required this.action});
  final FarmAction action;
  static String label(FarmActionKind kind) => switch (kind) {
        FarmActionKind.recordWeight => 'Catat bobot awal',
        FarmActionKind.checkWeight => 'Periksa ulang bobot',
        FarmActionKind.calculateFeed => 'Buat rencana pakan',
        FarmActionKind.refreshFeed => 'Perbarui rencana pakan',
        FarmActionKind.reviewFeedContext => 'Tinjau dukungan pakan',
      };
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          padding: 4,
          child: ListTile(
            key: ValueKey('farm-action-${action.cattle.id}'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: CattleAvatar(cattle: action.cattle, size: 42),
            title: Text(
              action.cattle.nameOrId,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              label(action.kind),
              style: TextStyle(
                color:
                    action.needsWeight ? AppColors.warning : AppColors.primary,
              ),
            ),
            trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                  builder: (_) =>
                      action.kind == FarmActionKind.reviewFeedContext
                          ? (action.cattle.productionCategory ==
                                  ProductionCategory.beef
                              ? BeefModuleScreen(
                                  cattleId: action.cattle.id,
                                  initial: BeefSection.feeding)
                              : DairyModuleScreen(
                                  cattleId: action.cattle.id,
                                  initial: DairySection.feeding))
                          : action.needsWeight
                              ? CattleProfileScreen(
                                  cattle: action.cattle,
                                  initialSection: CattleProfileSection.weight,
                                )
                              : IndividualFeedEntryScreen(
                                  cattleId: action.cattle.id)),
            ),
          ),
        ),
      );
}
