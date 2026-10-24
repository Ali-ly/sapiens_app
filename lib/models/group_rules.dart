import 'cattle_rules.dart';
import 'farm_snapshot.dart';
import 'feed_plan.dart';
import 'group_feed_plan.dart';
import 'livestock_group.dart';

class GroupRules {
  static void validateGroup(LivestockGroup group) {
    final ids = <String>{};
    DateTime? previous;
    if (group.id.trim().isEmpty) {
      throw const FormatException('ID kelompok tidak valid.');
    }
    for (final record in group.history) {
      if (record.id.isEmpty ||
          !ids.add(record.id) ||
          record.name.trim().isEmpty ||
          record.name.trim().length > 60 ||
          record.headCount < 0 ||
          record.headCount > 1000000 ||
          record.notes.length > 500 ||
          record.averageWeightKg != null &&
              !CattleRules.isValidWeight(record.averageWeightKg!) ||
          !targetLabels.containsKey(record.target) ||
          record.recordedAt.isBefore(group.createdAt) ||
          previous != null && record.recordedAt.isBefore(previous) ||
          record.archivedAt != null &&
              (record.archivedAt!.isBefore(group.createdAt) ||
                  record.archivedAt!.isAfter(record.recordedAt)) ||
          !{'manual', 'migration', 'archive', 'restore'}
              .contains(record.source)) {
        throw const FormatException('Data atau histori kelompok tidak valid.');
      }
      previous = record.recordedAt;
    }
  }

  static void validatePlan(GroupFeedPlan plan, LivestockGroup group) {
    final inputs = group.history.where((r) => r.id == plan.inputRevision);
    if (plan.id.isEmpty ||
        inputs.isEmpty ||
        plan.groupId != group.id ||
        plan.headCount <= 0 ||
        plan.headCount != inputs.first.headCount ||
        plan.averageWeightKg != inputs.first.averageWeightKg ||
        plan.target != inputs.first.target ||
        plan.createdAt.isBefore(inputs.first.recordedAt) ||
        !plan.totalFreshKg.isFinite ||
        plan.totalFreshKg <= 0 ||
        plan.availableFeeds.isEmpty ||
        plan.availableFeeds.toSet().length != plan.availableFeeds.length ||
        plan.availableFeeds.any((key) => !feedLabels.containsKey(key)) ||
        plan.portions.isEmpty ||
        plan.portions.map((p) => p.key).toSet().length !=
            plan.portions.length ||
        plan.portions.any((p) =>
            !plan.availableFeeds.contains(p.key) ||
            !p.asFedKg.isFinite ||
            p.asFedKg < 0 ||
            p.dryMatterKg != null &&
                (!p.dryMatterKg!.isFinite || p.dryMatterKg! < 0) ||
            p.ratio != null &&
                (!p.ratio!.isFinite || p.ratio! < 0 || p.ratio! > 100)) ||
        plan.totalDryMatterKg != null &&
            (!plan.totalDryMatterKg!.isFinite || plan.totalDryMatterKg! <= 0)) {
      throw const FormatException('Rencana pakan kelompok tidak valid.');
    }
  }

  static void validate(FarmSnapshot snapshot) {
    final groups = <String, LivestockGroup>{};
    final names = <String>{};
    for (final group in snapshot.groups) {
      validateGroup(group);
      if (groups.containsKey(group.id) ||
          !names.add(group.name.toLowerCase().trim())) {
        throw const FormatException('ID atau nama kelompok duplikat.');
      }
      groups[group.id] = group;
    }
    final ids = <String>{};
    for (final plan in snapshot.groupFeedPlans) {
      final group = groups[plan.groupId];
      if (group == null || !ids.add(plan.id)) {
        throw const FormatException('Relasi rencana kelompok tidak valid.');
      }
      validatePlan(plan, group);
    }
  }
}
