import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../models/cattle.dart';
import '../models/cattle_rules.dart';
import '../models/farm_snapshot.dart';
import '../models/feed_plan.dart';
import '../models/feed_plan_rules.dart';
import '../models/group_feed_plan.dart';
import '../models/group_rules.dart';
import '../models/legacy_group_membership.dart';
import '../models/livestock_group.dart';
import '../models/selected_image.dart';
import 'legacy_group_migration.dart';

/// Owns the persisted JSON schema. The same decoder validates imports and disk reads.
class FarmBackupCodec {
  static Map<String, dynamic> encode(FarmSnapshot snapshot,
          {DateTime? exportedAt}) =>
      {
        'schemaVersion': 4,
        'farmer': snapshot.farmer,
        'farm': snapshot.farm,
        'reminderDays': snapshot.reminderDays,
        'demo': snapshot.hasExamples,
        if (exportedAt != null) 'exportedAt': exportedAt.toIso8601String(),
        'cattle': snapshot.cattle.map(_encodeCattle).toList(),
        'feedPlans': snapshot.feedPlans.map((plan) => plan.toJson()).toList(),
        'groups': snapshot.groups.map((group) => group.toJson()).toList(),
        'groupFeedPlans':
            snapshot.groupFeedPlans.map((plan) => plan.toJson()).toList(),
        'legacyMemberships': snapshot.legacyMemberships
            .map((membership) => membership.toJson())
            .toList(),
      };
  static FarmSnapshot decode(String raw, {DateTime? migratedAt}) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Format cadangan tidak dikenali.');
      }
      if (decoded['schemaVersion'] != null &&
          decoded['schemaVersion'] != 2 &&
          decoded['schemaVersion'] != 3 &&
          decoded['schemaVersion'] != 4) {
        throw const FormatException('Versi cadangan belum didukung.');
      }
      final items = (decoded['cattle'] as List)
          .map((e) => _decodeCattle(Map<String, dynamic>.from(e as Map)))
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
      final version = decoded['schemaVersion'];
      if ((version == 3 &&
              (decoded['groups'] is! List ||
                  decoded['memberships'] is! List)) ||
          (version == 4 &&
              (decoded['groups'] is! List ||
                  decoded['legacyMemberships'] is! List ||
                  decoded['groupFeedPlans'] is! List))) {
        throw const FormatException(
            'Data kelompok dalam cadangan tidak lengkap.');
      }
      final legacy = ((version == 4
                  ? decoded['legacyMemberships']
                  : decoded['memberships']) as List? ??
              [])
          .map((value) => LegacyGroupMembership.fromJson(
              Map<String, dynamic>.from(value as Map)))
          .toList();
      final rawGroups = decoded['groups'] as List? ?? [];
      final groups = version == 4
          ? rawGroups
              .map((value) => LivestockGroup.fromJson(
                  Map<String, dynamic>.from(value as Map)))
              .toList()
          : LegacyGroupMigration.migrate(
              rawGroups, legacy, items, migratedAt ?? DateTime.now());
      final groupPlans = version == 4
          ? (decoded['groupFeedPlans'] as List)
              .map((value) => GroupFeedPlan.fromJson(
                  Map<String, dynamic>.from(value as Map)))
              .toList()
          : <GroupFeedPlan>[];
      final snapshot = FarmSnapshot(
        farmer: decoded['farmer'] as String,
        farm: decoded['farm'] as String,
        reminderDays: days,
        cattle: items,
        feedPlans: plans,
        groups: groups,
        legacyMemberships: legacy,
        groupFeedPlans: groupPlans,
      );
      GroupRules.validate(snapshot);
      return snapshot;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Cadangan tidak dapat dibaca. Gunakan JSON hasil ekspor SAPIENS.',
      );
    }
  }

  static Map<String, dynamic> _encodeCattle(Cattle c) => {
        'id': c.id,
        'name': c.nameOrId,
        'gender': c.gender,
        'age': c.ageMonths,
        'notes': c.notes,
        'weight': c.estimatedWeight,
        'spread': c.predictionSpread,
        'valid': c.validImages,
        'rejected': c.rejectedImages,
        'history': c.history
            .map(
              (r) => {
                'weight': r.weightKg,
                'date': r.date.toIso8601String(),
                'source': r.source
              },
            )
            .toList(),
        'images': c.images
            .map((i) => {'name': i.file.name, 'bytes': base64Encode(i.bytes)})
            .toList(),
      };
  static Cattle _decodeCattle(Map<String, dynamic> json) => Cattle(
        id: json['id'] as String,
        nameOrId: json['name'] as String,
        gender: json['gender'] as String,
        ageMonths: json['age'] as int,
        notes: json['notes'] as String? ?? '',
        estimatedWeight: (json['weight'] as num?)?.toDouble(),
        predictionSpread: (json['spread'] as num?)?.toDouble(),
        validImages: json['valid'] as int? ?? 0,
        rejectedImages: json['rejected'] as int? ?? 0,
        history: (json['history'] as List).map(
          (value) {
            final record = Map<String, dynamic>.from(value as Map);
            return WeightRecord(
              weightKg: (record['weight'] as num).toDouble(),
              date: DateTime.parse(record['date'] as String),
              source: record['source'] as String? ?? 'unknown',
            );
          },
        ).toList(),
        images: (json['images'] as List).map(
          (value) {
            final image = Map<String, dynamic>.from(value as Map);
            final bytes = base64Decode(image['bytes'] as String);
            return SelectedImage(
              file: XFile.fromData(bytes, name: image['name'] as String),
              bytes: bytes,
            );
          },
        ).toList(),
      );
}
