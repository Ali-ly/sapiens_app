import 'cattle.dart';
import 'feed_plan.dart';
import 'feed_stock.dart';
import 'group_feed_plan.dart';
import 'legacy_group_membership.dart';
import 'livestock_group.dart';

export 'production.dart';

/// A complete, immutable version of the data written to local storage.
enum FarmIdentityOrigin { localRandom, legacyDerived }

class FarmSnapshot {
  FarmSnapshot({
    this.farmId = '',
    this.farmIdentityOrigin = FarmIdentityOrigin.legacyDerived,
    this.farmer = 'Peternak',
    this.farm = 'Peternakan Saya',
    this.reminderDays = 7,
    this.productionSystems,
    List<Cattle> cattle = const [],
    List<StockEntry> feedStock = const [],
    List<FeedPlan> feedPlans = const [],
    List<LivestockGroup> groups = const [],
    List<GroupFeedPlan> groupFeedPlans = const [],
    List<LegacyGroupMembership> legacyMemberships = const [],
  })  : feedStock = List.unmodifiable(feedStock),
        cattle = List.unmodifiable(cattle),
        feedPlans = List.unmodifiable(feedPlans),
        groups = List.unmodifiable(groups),
        groupFeedPlans = List.unmodifiable(groupFeedPlans),
        legacyMemberships = List.unmodifiable(legacyMemberships);

  final String farmId;
  final FarmIdentityOrigin farmIdentityOrigin;
  final String farmer;
  final String farm;
  final int reminderDays;
  final FarmProductionSystems? productionSystems;
  final List<Cattle> cattle;
  final List<StockEntry> feedStock;
  final List<FeedPlan> feedPlans;
  final List<LivestockGroup> groups;
  final List<GroupFeedPlan> groupFeedPlans;
  final List<LegacyGroupMembership> legacyMemberships;

  FarmSnapshot copyWith(
          {String? farmer,
          String? farmId,
          FarmIdentityOrigin? farmIdentityOrigin,
          String? farm,
          int? reminderDays,
          FarmProductionSystems? productionSystems,
          List<Cattle>? cattle,
          List<StockEntry>? feedStock,
          List<FeedPlan>? feedPlans,
          List<LivestockGroup>? groups,
          List<GroupFeedPlan>? groupFeedPlans,
          List<LegacyGroupMembership>? legacyMemberships}) =>
      FarmSnapshot(
          farmId: farmId ?? this.farmId,
          farmIdentityOrigin: farmIdentityOrigin ?? this.farmIdentityOrigin,
          productionSystems: productionSystems ?? this.productionSystems,
          farmer: farmer ?? this.farmer,
          farm: farm ?? this.farm,
          reminderDays: reminderDays ?? this.reminderDays,
          cattle: cattle ?? this.cattle,
          feedStock: feedStock ?? this.feedStock,
          feedPlans: feedPlans ?? this.feedPlans,
          groups: groups ?? this.groups,
          groupFeedPlans: groupFeedPlans ?? this.groupFeedPlans,
          legacyMemberships: legacyMemberships ?? this.legacyMemberships);

  bool get hasExamples =>
      cattle.any((animal) => animal.isActive && animal.id.startsWith('demo-'));
}
