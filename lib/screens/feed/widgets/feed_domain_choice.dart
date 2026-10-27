import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/production.dart';

/// The same accessible domain entry is used by the hub and direct feed routes.
class FeedDomainChoice extends StatelessWidget {
  const FeedDomainChoice({
    super.key,
    required this.beefCount,
    required this.dairyCount,
    required this.onSelected,
    required this.keyPrefix,
  });

  final int beefCount, dairyCount;
  final ValueChanged<ProductionCategory> onSelected;
  final String keyPrefix;

  Widget card(ProductionCategory category) {
    final beef = category == ProductionCategory.beef;
    final count = beef ? beefCount : dairyCount;
    return OutlinedButton(
        key: ValueKey('$keyPrefix-${category.name}'),
        style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
            padding: const EdgeInsets.all(22),
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24))),
        onPressed: () => onSelected(category),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: beef
                            ? AppColors.primarySoft
                            : AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(
                        beef ? Icons.grass_rounded : Icons.water_drop_outlined,
                        color: AppColors.primary)),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ]),
              const SizedBox(height: 18),
              Text(beef ? 'Sapi Pedaging' : 'Sapi Perah',
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  beef
                      ? 'Pakan untuk sapi pedaging, dari pertumbuhan hingga pembibitan.'
                      : 'Pakan untuk sapi perah, sesuai fase yang tercatat.',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              Text(count == 0 ? 'Belum ada sapi aktif' : '$count sapi aktif',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ]));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        if (size.maxWidth >= 560) {
          return IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Expanded(child: card(ProductionCategory.beef)),
                const SizedBox(width: 14),
                Expanded(child: card(ProductionCategory.dairy)),
              ]));
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card(ProductionCategory.beef),
              const SizedBox(height: 14),
              card(ProductionCategory.dairy),
            ]);
      });
}
