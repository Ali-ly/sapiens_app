import 'beef/beef_feed_context.dart';
import 'cattle.dart';
import 'feed_plan.dart';
import 'persisted_time.dart';

/// Shared operational rules for the dashboard, feed totals and cattle lists.
class FarmStatus {
  static bool needsWeightCheck(Cattle animal, DateTime now, int reminderDays) =>
      animal.isActive &&
      (animal.estimatedWeight == null ||
          animal.history.isEmpty ||
          animal.productionCategory == ProductionCategory.beef &&
              (animal.history.last.date.isAfter(now) ||
                  animal.history.last.timestampBasis ==
                      TimestampBasis.legacyLocalUnknown) ||
          now.difference(animal.history.last.date).inDays >= reminderDays);

  static FeedPlan? latestPlan(Iterable<FeedPlan> plans, String cattleId) {
    FeedPlan? latest;
    for (final plan in plans) {
      if (plan.cattleId == cattleId &&
          (latest == null || !plan.createdAt.isBefore(latest.createdAt))) {
        latest = plan;
      }
    }
    return latest;
  }

  static bool planReady(
          Cattle animal, FeedPlan? plan, DateTime now, int reminderDays) =>
      animal.isActive &&
      plan?.isNutritionEvaluation == false &&
      plan?.matches(animal) == true &&
      (animal.productionCategory == null ||
          BeefFeedContext.limitation(animal, plan!.target!) == null &&
              plan.beefContext != null &&
              !plan.createdAt.isAfter(now)) &&
      !needsWeightCheck(animal, now, reminderDays);
}
