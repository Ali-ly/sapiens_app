import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../application/nutrition_context.dart';
import '../../domain/cattle.dart';
import '../../domain/condition.dart';
import '../../domain/milk_metrics.dart';
import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/avatar.dart';
import '../../ui/components.dart';
import 'profile_page.dart';

class CattleCard extends StatelessWidget {
  const CattleCard(
      {super.key,
      required this.cattle,
      required this.mode,
      required this.now,
      this.onTap});
  final Cattle cattle;
  final FarmMode mode;
  final DateTime now;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final latest = cattle.evaluations.lastOrNull;
    final evaluation = latest == null
        ? 'Belum ada evaluasi'
        : NutritionContext(mode, cattle, now).isCurrent(latest)
            ? 'Evaluasi sesuai konteks'
            : 'Perlu evaluasi ulang';
    final condition = cattle.condition;
    final milk = mode == FarmMode.dairy && cattle.sex == Sex.female
        ? MilkMetrics(cattle, now)
        : null;
    return Surface(
        onTap: onTap ??
            () => openPage(context, CattleProfilePage(cattleId: cattle.id)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CowAvatar(cattle: cattle),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(cattle.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                if (cattle.userId.isNotEmpty)
                  Text('ID ${cattle.userId}',
                      style:
                          const TextStyle(fontSize: 12, color: Palette.muted)),
                const SizedBox(height: 5),
                Text('${cattle.sex.label} · ${cattle.ageMonths} bulan'),
                Text('${number(cattle.latestWeight.kg)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (condition is BeefCondition)
                  Text(
                      '${condition.purpose.label}${condition.phase == null ? '' : ' · ${condition.phase!.label}'}',
                      style:
                          const TextStyle(fontSize: 12, color: Palette.muted)),
                if (condition is DairyCondition && cattle.sex == Sex.female)
                  Text(condition.stage?.label ?? 'Fase belum dipilih',
                      style:
                          const TextStyle(fontSize: 12, color: Palette.muted)),
                if (milk?.latest != null &&
                    (condition as DairyCondition).stage?.lactating == true)
                  Text(
                      'Susu ${number(milk!.latest!.recordedAmount)} ${milk.latest!.unit.label} · ${milk.latest!.complete ? 'lengkap' : 'parsial'}',
                      style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Tag(cattle.active ? evaluation : 'Diarsipkan',
                    warning: !cattle.active ||
                        latest != null &&
                            !NutritionContext(mode, cattle, now)
                                .isCurrent(latest)),
                if (milk?.holds.isNotEmpty == true)
                  const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Tag('Masa tahan susu aktif', warning: true))
              ])),
          const Icon(Icons.chevron_right, size: 20)
        ]));
  }
}
