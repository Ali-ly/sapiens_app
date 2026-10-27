import '../data/json_value.dart';
import 'beef/beef_feed_context.dart';
import 'cattle_rules.dart';
import 'feed_plan.dart';
import 'production.dart';

class FeedPlanRules {
  static const bodyConditions = {'Kurus', 'Sedang', 'Gemuk', 'Tidak tahu'};

  static void validate(FeedPlan plan) {
    if (plan.isNutritionEvaluation) {
      final request = plan.nutritionRequest;
      if (request == null) {
        throw const FormatException('Input evaluasi belum tersedia.');
      }
      if (plan.nutritionSnapshot == null ||
          plan.beefContext != null ||
          plan.productionCategory != request.productionCategory ||
          request.cattle.bodyWeightKg != plan.weightKg ||
          plan.id.isEmpty ||
          plan.cattleId.isEmpty ||
          plan.cattleName.trim().isEmpty ||
          !CattleRules.isValidWeight(plan.weightKg) ||
          !CattleRules.genders.contains(plan.gender) ||
          plan.ageMonths < 1 ||
          plan.ageMonths > CattleRules.maximumAgeMonths ||
          plan.target != null ||
          plan.bodyCondition != null ||
          !plan.totalFreshKg.isFinite ||
          request.feedItems.isEmpty ||
          request.feedItems.any((f) => f.asFedKgDay <= 0) ||
          request.feedItems.map((f) => f.feedId).toSet().length !=
              request.feedItems.length ||
          !sameJson(plan.availableFeeds,
              request.feedItems.map((f) => f.feedId).toList()) ||
          !sameJson(
              plan.portions.map((p) => p.toJson()).toList(),
              request.feedItems
                  .map((f) => FeedPortion(key: f.feedId, asFedKg: f.asFedKgDay)
                      .toJson())
                  .toList()) ||
          plan.totalDryMatterKg != null ||
          plan.warning != null ||
          plan.notes.isNotEmpty) {
        throw const FormatException(
            'Snapshot evaluasi nutrisi tidak sesuai input.');
      }
      return;
    }
    if (plan.nutritionRequest != null) {
      throw const FormatException('Tipe evaluasi tidak sesuai input.');
    }
    if (plan.nutritionSnapshot != null &&
        plan.beefContext != null &&
        plan.productionCategory != ProductionCategory.beef) {
      throw const FormatException(
          'Snapshot Dairy tidak sesuai konteks rencana Beef.');
    }
    if (plan.beefContext != null) {
      BeefFeedContext.fromJson(plan.beefContext!.toJson());
    }
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
