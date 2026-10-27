import '../models/beef/beef_rules.dart';
import '../models/cattle_rules.dart';
import '../models/dairy/dairy_rules.dart';
import '../models/farm_snapshot.dart';
import '../models/feed_plan.dart';
import '../models/feed_plan_rules.dart';
import '../models/feed_stock.dart';
import '../models/group_feed_plan.dart';
import '../models/group_rules.dart';
import '../models/legacy_group_membership.dart';
import '../models/livestock_group.dart';
import '../models/twin_rules.dart';
import 'cattle_codec.dart';
import 'farm_payload_shape.dart';
import 'legacy_group_migration.dart';
import 'twin_codec.dart';

/// Owns the persisted JSON schema. The same decoder validates imports and disk reads.
class FarmPayloadCodec {
  static FarmSnapshot decode(Map<String, dynamic> decoded,
      {required int schemaVersion,
      required int foundationVersion,
      bool requireIdentity = false}) {
    try {
      FarmPayloadShape.validate(decoded, schemaVersion);
      final items = (decoded['cattle'] as List)
          .map((e) => CattleCodec.decode(Map<String, dynamic>.from(e as Map),
              foundationVersion: foundationVersion > 2 ? 2 : foundationVersion))
          .toList();
      final ids = <String>{}, names = <String>{};
      for (final c in items) {
        CattleRules.validate(c);
        if (!ids.add(c.id) || !names.add(c.nameOrId.trim().toLowerCase())) {
          throw const FormatException(
            'Identitas sapi dalam cadangan duplikat.',
          );
        }
      }
      final plans = (decoded['feedPlans'] as List? ?? [])
          .map((e) => FeedPlan.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final planIds = <String>{};
      for (final plan in plans) {
        FeedPlanRules.validate(plan);
        if (!ids.contains(plan.cattleId) || !planIds.add(plan.id)) {
          throw const FormatException(
            'Rencana pakan tidak memiliki sapi yang sesuai atau ID-nya duplikat.',
          );
        }
      }
      if (decoded['farmer'] is! String ||
          (decoded['farmer'] as String).trim().isEmpty ||
          decoded['farm'] is! String ||
          (decoded['farm'] as String).trim().isEmpty) {
        throw const FormatException(
          'Identitas peternakan dalam cadangan tidak lengkap.',
        );
      }
      final days = decoded['reminderDays'] ?? 7;
      if (days is! int || !CattleRules.reminderIntervals.contains(days)) {
        throw const FormatException('Interval pengecekan tidak valid.');
      }
      final version = schemaVersion;
      if ((version == 3 &&
              (decoded['groups'] is! List ||
                  decoded['memberships'] is! List)) ||
          (version >= 4 &&
              (decoded['groups'] is! List ||
                  decoded['legacyMemberships'] is! List ||
                  decoded['groupFeedPlans'] is! List))) {
        throw const FormatException(
            'Data kelompok dalam cadangan tidak lengkap.');
      }
      final legacy = ((version >= 4
                  ? decoded['legacyMemberships']
                  : decoded['memberships']) as List? ??
              [])
          .map((value) => LegacyGroupMembership.fromJson(
              Map<String, dynamic>.from(value as Map)))
          .toList();
      final rawGroups = decoded['groups'] as List? ?? [];
      final groups = version >= 4
          ? rawGroups
              .map((value) => LivestockGroup.fromJson(
                  Map<String, dynamic>.from(value as Map)))
              .toList()
          : LegacyGroupMigration.migrate(rawGroups, legacy, items);
      final groupPlans = version >= 4
          ? (decoded['groupFeedPlans'] as List)
              .map((value) => GroupFeedPlan.fromJson(
                  Map<String, dynamic>.from(value as Map)))
              .toList()
          : <GroupFeedPlan>[];
      FarmProductionSystems? productionSystems;
      if (decoded.containsKey('foundation')) {
        final foundation = TwinCodec.object(decoded['foundation'], {
          'version',
          'productionSystems',
          if (foundationVersion >= 3) 'feedStock'
        });
        TwinCodec.version(foundation, expected: foundationVersion);
        if (foundation['productionSystems'] != null) {
          productionSystems = FarmProductionSystems.values
              .byName(foundation['productionSystems'] as String);
        }
      }
      if (items.any(TwinCodec.hasFoundation) &&
          !decoded.containsKey('foundation')) {
        throw const FormatException('Versi fondasi peternakan tidak tersedia.');
      }
      if (requireIdentity &&
          (decoded['farmId'] is! String ||
              (decoded['farmId'] as String).trim().isEmpty ||
              decoded['farmIdentityOrigin'] is! String ||
              decoded['foundation'] == null)) {
        throw const FormatException('Identitas schema 5 tidak lengkap.');
      }
      final snapshot = FarmSnapshot(
        farmId: decoded['farmId'] as String? ?? '',
        farmIdentityOrigin: decoded['farmIdentityOrigin'] == null
            ? FarmIdentityOrigin.legacyDerived
            : FarmIdentityOrigin.values
                .byName(decoded['farmIdentityOrigin'] as String),
        productionSystems: productionSystems,
        farmer: decoded['farmer'] as String,
        farm: decoded['farm'] as String,
        reminderDays: days,
        cattle: items,
        feedStock: foundationVersion >= 3
            ? TwinCodec.records((decoded['foundation'] as Map)['feedStock'],
                StockEntry.fromJson)
            : const [],
        feedPlans: plans,
        groups: groups,
        legacyMemberships: legacy,
        groupFeedPlans: groupPlans,
      );
      GroupRules.validate(snapshot);
      BeefRules.validate(snapshot);
      DairyRules.validate(snapshot);
      TwinRules.validate(snapshot, requireStableIdentity: requireIdentity);
      return snapshot;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Cadangan tidak dapat dibaca. Gunakan JSON hasil ekspor SAPIENS.',
      );
    }
  }
}
