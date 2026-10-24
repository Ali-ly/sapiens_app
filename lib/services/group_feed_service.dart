import 'package:http/http.dart' as http;

import '../models/feed_plan.dart';
import '../models/group_feed_plan.dart';
import '../models/group_rules.dart';
import '../models/livestock_group.dart';
import 'feed_ration.dart';
import 'feed_service.dart';

class GroupFeedService {
  static int _counter = 0;
  static Future<GroupFeedPlan> calculate(
      {required LivestockGroup group,
      required List<String> availableFeeds,
      http.Client? client}) async {
    GroupRules.validateGroup(group);
    if (!group.canCalculateFeed) {
      throw const FormatException(
          'Isi jumlah sapi dan bobot rata-rata sebelum menghitung pakan.');
    }
    if (availableFeeds.isEmpty ||
        availableFeeds.toSet().length != availableFeeds.length ||
        availableFeeds.any((key) => !feedLabels.containsKey(key)) ||
        !availableFeeds.contains('rumput') &&
            !availableFeeds.contains('jerami')) {
      throw const FormatException(
          'Pilih bahan yang dikenal dan minimal satu sumber serat.');
    }
    final response = await FeedService.calculateFeed(
        weight: group.averageWeightKg!,
        target: group.target,
        availableFeeds: availableFeeds,
        client: client);
    final ration = FeedRation.parse(
        weight: group.averageWeightKg!,
        target: group.target,
        feeds: availableFeeds,
        data: response);
    final now = DateTime.now().toUtc();
    final plan = GroupFeedPlan(
        id: 'group-plan-${now.microsecondsSinceEpoch}-${_counter++}',
        groupId: group.id,
        inputRevision: group.inputRevision,
        headCount: group.headCount,
        averageWeightKg: group.averageWeightKg!,
        target: group.target,
        createdAt: now,
        availableFeeds: availableFeeds,
        portions: ration.portions,
        totalDryMatterKg: ration.totalDryMatterKg,
        warning: ration.warning,
        notes: ration.notes);
    GroupRules.validatePlan(plan, group);
    return plan;
  }
}
