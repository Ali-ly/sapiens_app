import 'feed_plan.dart';
import 'livestock_group.dart';
import 'persisted_time.dart';

/// API ration per animal, with the exact bulk inputs used for multiplication.
class GroupFeedPlan {
  GroupFeedPlan(
      {required this.id,
      required this.groupId,
      required this.inputRevision,
      required this.headCount,
      required this.averageWeightKg,
      required this.target,
      required this.createdAt,
      this.createdAtText,
      required List<String> availableFeeds,
      required List<FeedPortion> portions,
      this.totalDryMatterKg,
      this.warning,
      List<String> notes = const []})
      : availableFeeds = List.unmodifiable(availableFeeds),
        portions = List.unmodifiable(portions),
        notes = List.unmodifiable(notes);
  final String id, groupId, inputRevision, target;
  final int headCount;
  final double averageWeightKg;
  final String? createdAtText;
  final DateTime createdAt;
  final List<String> availableFeeds, notes;
  final List<FeedPortion> portions;
  final double? totalDryMatterKg;
  final String? warning;
  double get freshKgPerHead => portions.fold(0.0, (sum, p) => sum + p.asFedKg);
  double get totalFreshKg => freshKgPerHead * headCount;
  List<FeedPortion> get groupPortions =>
      List.unmodifiable(portions.map((p) => FeedPortion(
          key: p.key,
          asFedKg: p.asFedKg * headCount,
          dryMatterKg:
              p.dryMatterKg == null ? null : p.dryMatterKg! * headCount,
          ratio: p.ratio)));
  bool matches(LivestockGroup group) =>
      group.id == groupId &&
      group.canCalculateFeed &&
      group.inputRevision == inputRevision &&
      group.headCount == headCount &&
      group.averageWeightKg == averageWeightKg &&
      group.target == target;
  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'inputRevision': inputRevision,
        'headCount': headCount,
        'averageWeightKg': averageWeightKg,
        'target': target,
        'createdAt': PersistedTime.encode(createdAt, createdAtText),
        'availableFeeds': availableFeeds,
        'portions': portions.map((p) => p.toJson()).toList(),
        'totalDryMatterKg': totalDryMatterKg,
        'warning': warning,
        'notes': notes
      };
  factory GroupFeedPlan.fromJson(Map<String, dynamic> json) => GroupFeedPlan(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      inputRevision: json['inputRevision'] as String,
      headCount: json['headCount'] as int,
      averageWeightKg: (json['averageWeightKg'] as num).toDouble(),
      target: json['target'] as String,
      createdAtText: json['createdAt'] as String,
      createdAt: PersistedTime.parse(json['createdAt'] as String),
      availableFeeds: List<String>.from(json['availableFeeds'] as List),
      portions: (json['portions'] as List)
          .map((p) => FeedPortion.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      totalDryMatterKg: (json['totalDryMatterKg'] as num?)?.toDouble(),
      warning: json['warning'] as String?,
      notes: List<String>.from(json['notes'] as List));
}
