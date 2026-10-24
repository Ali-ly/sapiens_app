import 'cattle.dart';
import 'farm_snapshot.dart';
import 'farm_status.dart';
import 'feed_plan.dart';

enum FarmActionKind { recordWeight, checkWeight, calculateFeed, refreshFeed }

enum FarmActivityKind { weight, feedPlan }

/// One next step per animal. This is derived work, not a persisted task system.
class FarmAction {
  const FarmAction({required this.cattle, required this.kind});
  final Cattle cattle;
  final FarmActionKind kind;
  bool get needsWeight =>
      kind == FarmActionKind.recordWeight || kind == FarmActionKind.checkWeight;
}

class FarmActivity {
  const FarmActivity(
      {required this.cattle,
      required this.date,
      required this.kind,
      this.weightKg,
      this.source,
      this.plan});
  final Cattle cattle;
  final DateTime date;
  final FarmActivityKind kind;
  final double? weightKg;
  final String? source;
  final FeedPlan? plan;
}

/// Read-only projection of existing farm data. No additional storage schema.
class FarmCommandCenter {
  FarmCommandCenter._(
      {required this.asOf,
      required this.cattleCount,
      required this.unweighedCount,
      required this.dueCount,
      required this.readyCount,
      required this.recordedWeightKg,
      required List<FarmAction> actions,
      required List<FarmActivity> activity,
      required Map<String, double> dailyFeedTotals})
      : actions = List.unmodifiable(actions),
        activity = List.unmodifiable(activity),
        dailyFeedTotals = Map.unmodifiable(dailyFeedTotals);

  final DateTime asOf;
  final int cattleCount, unweighedCount, dueCount, readyCount;
  final double recordedWeightKg;
  final List<FarmAction> actions;
  final List<FarmActivity> activity;
  final Map<String, double> dailyFeedTotals;
  int get feedAttentionCount => cattleCount - readyCount;
  int get weightAttentionCount => unweighedCount + dueCount;
  double get feedCoverage => cattleCount == 0 ? 0 : readyCount / cattleCount;
  double get dailyFreshKg =>
      dailyFeedTotals.values.fold(0.0, (sum, kg) => sum + kg);

  factory FarmCommandCenter.fromSnapshot(FarmSnapshot snapshot, DateTime now) {
    var unweighed = 0, due = 0, ready = 0;
    var weight = 0.0;
    final actions = <FarmAction>[];
    final activity = <FarmActivity>[];
    final totals = <String, double>{};
    for (final animal in snapshot.cattle) {
      final latest = FarmStatus.latestPlan(snapshot.feedPlans, animal.id);
      weight += animal.estimatedWeight ?? 0;
      if (animal.estimatedWeight == null || animal.history.isEmpty) {
        unweighed++;
        actions
            .add(FarmAction(cattle: animal, kind: FarmActionKind.recordWeight));
      } else if (FarmStatus.needsWeightCheck(
        animal,
        now,
        snapshot.reminderDays,
      )) {
        due++;
        actions
            .add(FarmAction(cattle: animal, kind: FarmActionKind.checkWeight));
      } else if (latest == null) {
        actions.add(
          FarmAction(cattle: animal, kind: FarmActionKind.calculateFeed),
        );
      } else if (!latest.matches(animal)) {
        actions
            .add(FarmAction(cattle: animal, kind: FarmActionKind.refreshFeed));
      }
      if (FarmStatus.planReady(animal, latest, now, snapshot.reminderDays)) {
        ready++;
        for (final portion in latest!.portions) {
          totals.update(
            portion.key,
            (kg) => kg + portion.asFedKg,
            ifAbsent: () => portion.asFedKg,
          );
        }
      }
      for (final record in animal.history.where((r) => !r.date.isAfter(now))) {
        activity.add(
          FarmActivity(
            cattle: animal,
            date: record.date,
            kind: FarmActivityKind.weight,
            weightKg: record.weightKg,
            source: record.source,
          ),
        );
      }
      for (final plan in snapshot.feedPlans
          .where((p) => p.cattleId == animal.id && !p.createdAt.isAfter(now))) {
        activity.add(
          FarmActivity(
            cattle: animal,
            date: plan.createdAt,
            kind: FarmActivityKind.feedPlan,
            plan: plan,
          ),
        );
      }
    }
    actions.sort(
      (a, b) {
        final priority = a.kind.index.compareTo(b.kind.index);
        if (priority != 0) {
          return priority;
        }
        if (a.cattle.history.isNotEmpty && b.cattle.history.isNotEmpty) {
          final oldest =
              a.cattle.history.last.date.compareTo(b.cattle.history.last.date);
          if (oldest != 0) {
            return oldest;
          }
        }
        final name = a.cattle.nameOrId.compareTo(b.cattle.nameOrId);
        return name == 0 ? a.cattle.id.compareTo(b.cattle.id) : name;
      },
    );
    activity.sort(
      (a, b) {
        final date = b.date.compareTo(a.date);
        if (date != 0) {
          return date;
        }
        final id = a.cattle.id.compareTo(b.cattle.id);
        return id == 0 ? a.kind.index.compareTo(b.kind.index) : id;
      },
    );
    return FarmCommandCenter._(
      asOf: now,
      cattleCount: snapshot.cattle.length,
      unweighedCount: unweighed,
      dueCount: due,
      readyCount: ready,
      recordedWeightKg: weight,
      actions: actions,
      activity: activity,
      dailyFeedTotals: totals,
    );
  }
}
