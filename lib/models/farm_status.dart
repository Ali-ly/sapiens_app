import 'cattle.dart';
import 'feed_plan.dart';

/// Shared operational rules for the dashboard, feed totals and cattle lists.
class FarmStatus {
  static bool needsWeightCheck(Cattle animal, DateTime now, int reminderDays) =>
      animal.estimatedWeight == null ||
      animal.history.isEmpty ||
      now.difference(animal.history.last.date).inDays >= reminderDays;

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
      plan?.matches(animal) == true &&
      !needsWeightCheck(animal, now, reminderDays);
}
