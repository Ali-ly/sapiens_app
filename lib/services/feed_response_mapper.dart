import '../models/cattle.dart';
import '../models/cattle_rules.dart';
import '../models/feed_plan.dart';
import '../models/feed_plan_rules.dart';
import 'feed_ration.dart';

/// Converts the gateway response into a validated plan snapshot.
class FeedResponseMapper {
  static int _idCounter = 0;
  static FeedPlan parse(
      {required Cattle cattle,
      required String target,
      required String condition,
      required List<String> feeds,
      required Map<String, dynamic> data}) {
    CattleRules.validate(cattle);
    if (cattle.estimatedWeight == null) {
      throw const FormatException('Catat bobot sapi sebelum menghitung pakan.');
    }
    final ration = FeedRation.parse(
        weight: cattle.estimatedWeight!,
        target: target,
        feeds: feeds,
        data: data);
    final now = DateTime.now();
    final plan = FeedPlan(
      id: '${now.microsecondsSinceEpoch}-${_idCounter++}',
      cattleId: cattle.id,
      cattleName: cattle.nameOrId,
      weightKg: cattle.estimatedWeight!,
      ageMonths: cattle.ageMonths,
      gender: cattle.gender,
      bodyCondition: condition,
      target: target,
      availableFeeds: List.of(feeds),
      createdAt: now,
      weightDate: cattle.history.isEmpty ? null : cattle.history.last.date,
      portions: ration.portions,
      totalDryMatterKg: ration.totalDryMatterKg,
      warning: ration.warning,
      notes: ration.notes,
    );
    FeedPlanRules.validate(plan);
    return plan;
  }
}
