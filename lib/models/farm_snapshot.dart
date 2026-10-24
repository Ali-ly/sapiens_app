import 'cattle.dart';
import 'feed_plan.dart';
import 'group_feed_plan.dart';
import 'legacy_group_membership.dart';
import 'livestock_group.dart';

/// A complete, immutable version of the data written to local storage.
class FarmSnapshot {
  FarmSnapshot({
    this.farmer = 'Peternak',
    this.farm = 'Peternakan Saya',
    this.reminderDays = 7,
    List<Cattle> cattle = const [],
    List<FeedPlan> feedPlans = const [],
    List<LivestockGroup> groups = const [],
    List<GroupFeedPlan> groupFeedPlans = const [],
    List<LegacyGroupMembership> legacyMemberships = const [],
  })  : cattle = List.unmodifiable(cattle),
        feedPlans = List.unmodifiable(feedPlans),
        groups = List.unmodifiable(groups),
        groupFeedPlans = List.unmodifiable(groupFeedPlans),
        legacyMemberships = List.unmodifiable(legacyMemberships);

  final String farmer;
  final String farm;
  final int reminderDays;
  final List<Cattle> cattle;
  final List<FeedPlan> feedPlans;
  final List<LivestockGroup> groups;
  final List<GroupFeedPlan> groupFeedPlans;
  final List<LegacyGroupMembership> legacyMemberships;

  FarmSnapshot copyWith(
          {String? farmer,
          String? farm,
          int? reminderDays,
          List<Cattle>? cattle,
          List<FeedPlan>? feedPlans,
          List<LivestockGroup>? groups,
          List<GroupFeedPlan>? groupFeedPlans,
          List<LegacyGroupMembership>? legacyMemberships}) =>
      FarmSnapshot(
          farmer: farmer ?? this.farmer,
          farm: farm ?? this.farm,
          reminderDays: reminderDays ?? this.reminderDays,
          cattle: cattle ?? this.cattle,
          feedPlans: feedPlans ?? this.feedPlans,
          groups: groups ?? this.groups,
          groupFeedPlans: groupFeedPlans ?? this.groupFeedPlans,
          legacyMemberships: legacyMemberships ?? this.legacyMemberships);

  bool get hasExamples => cattle.any((animal) => animal.id.startsWith('demo-'));
}
