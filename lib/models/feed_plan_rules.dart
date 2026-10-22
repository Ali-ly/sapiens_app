import 'cattle_rules.dart';
import 'feed_plan.dart';

class FeedPlanRules {
  static const bodyConditions = {'Kurus', 'Sedang', 'Gemuk', 'Tidak tahu'};

  static void validate(FeedPlan plan) {
    if (plan.id.isEmpty ||
        plan.cattleId.isEmpty ||
        plan.cattleName.trim().isEmpty ||
        !CattleRules.isValidWeight(plan.weightKg) ||
        plan.ageMonths < 1 ||
        plan.ageMonths > CattleRules.maximumAgeMonths ||
        !CattleRules.genders.contains(plan.gender) ||
        !bodyConditions.contains(plan.bodyCondition) ||
        !targetLabels.containsKey(plan.target)) {
      throw const FormatException('Identitas rencana pakan tidak valid.');
    }
    if (plan.availableFeeds.isEmpty ||
        plan.availableFeeds.any((key) => !feedLabels.containsKey(key)) ||
        plan.portions.isEmpty) {
      throw const FormatException('Bahan rencana pakan tidak valid.');
    }
    final keys = <String>{};
    for (final portion in plan.portions) {
      if (!keys.add(portion.key) ||
          !plan.availableFeeds.contains(portion.key) ||
          !portion.asFedKg.isFinite ||
          portion.asFedKg < 0 ||
          portion.dryMatterKg != null &&
              (!portion.dryMatterKg!.isFinite || portion.dryMatterKg! < 0) ||
          portion.ratio != null &&
              (!portion.ratio!.isFinite ||
                  portion.ratio! < 0 ||
                  portion.ratio! > 100)) {
        throw const FormatException('Takaran rencana pakan tidak valid.');
      }
    }
    if (!plan.totalFreshKg.isFinite ||
        plan.totalFreshKg <= 0 ||
        plan.totalDryMatterKg != null &&
            (!plan.totalDryMatterKg!.isFinite || plan.totalDryMatterKg! <= 0)) {
      throw const FormatException(
        'Total takaran pakan harus lebih besar dari nol.',
      );
    }
  }
}
