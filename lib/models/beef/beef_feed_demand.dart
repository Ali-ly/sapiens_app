import '../farm_snapshot.dart';
import '../farm_status.dart';
import '../feed_plan.dart';
import '../feed_stock.dart';

/// Individual Beef scope only. Independent bulk groups may overlap and are
/// deliberately excluded. No automatic ledger consumption is inferred.
class BeefFeedDemand {
  BeefFeedDemand(FarmSnapshot farm, DateTime now, {this.days = 1}) {
    if (!{1, 7, 30}.contains(days)) {
      throw ArgumentError('Periode harus 1, 7, atau 30 hari.');
    }
    stock = StockEntry.balances(
        farm.feedStock.where((e) => !e.recordedAt.isAfter(now)));
    for (final c in farm.cattle.where(
        (c) => c.isActive && c.productionCategory == ProductionCategory.beef)) {
      total++;
      final plan = FarmStatus.latestPlan(farm.feedPlans, c.id);
      if (!FarmStatus.planReady(c, plan, now, farm.reminderDays) ||
          plan!.createdAt.isAfter(now)) {
        excluded.add(c.nameOrId);
        continue;
      }
      eligible++;
      for (final p in plan.portions) {
        daily.update(p.key, (v) => v + p.asFedKg, ifAbsent: () => p.asFedKg);
      }
    }
  }
  final int days;
  int total = 0, eligible = 0;
  final List<String> excluded = [];
  final Map<String, double> daily = {};
  late final Map<String, double> stock;
  double requiredKg(String feed) => (daily[feed] ?? 0) * days;
  double shortageKg(String feed) => (requiredKg(feed) - (stock[feed] ?? 0))
      .clamp(0, double.infinity)
      .toDouble();
  double? daysRemaining(String feed) =>
      (daily[feed] ?? 0) > 0 ? (stock[feed] ?? 0) / daily[feed]! : null;
  Iterable<String> get ingredients => feedLabels.keys;
}
