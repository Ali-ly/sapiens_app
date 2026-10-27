import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/data/cattle_codec.dart';
import 'package:sapita_app/data/farm_backup_codec.dart';
import 'package:sapita_app/models/farm_snapshot.dart';
import 'package:sapita_app/models/feed_api_v2.dart';
import 'package:sapita_app/models/feed_nutrition_snapshot.dart';
import 'package:sapita_app/models/feed_plan.dart';
import 'package:sapita_app/models/feed_plan_rules.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/beef_environment.dart';
import 'helpers/migration_fixtures.dart';

Map<String, dynamic> response() => {
      'requirement': {
        'energy': {'value': 55, 'unit': 'MJ/day'}
      },
      'supply': {'protein': null},
      'adequacy': {'status': 'partial'},
      'warnings': [
        'Coverage incomplete',
        {'code': 'UNKNOWN_PROFILE'}
      ],
      'coverage': {
        'known': ['dm'],
        'unknown': ['energy']
      },
      'assumptions': ['manual quantities'],
      'defaults_used': {'milk_fat_pct': 4},
      'future_field': {
        'provenance': ['backend']
      },
    };

FeedPlan attach(FeedPlan legacy, ProductionCategory category,
        {String? id, Map<String, dynamic>? result}) =>
    FeedPlan.fromJson({
      ...legacy.toJson(),
      if (id != null) 'id': id,
      'nutritionSnapshot': FeedNutritionSnapshot(
        productionCategory: category,
        response: NutritionResponse.fromJson(result ?? response()),
      ).toJson(),
    });

Future<(BeefEnvironment, FeedPlan)> environment() async {
  final e = BeefEnvironment();
  // No fixed historical wall clock for readiness in this new suite.
  e.now = DateTime.now().toUtc();
  await e.store.load();
  final c = await e.add('Snapshot cow');
  await e.setup(c.id);
  return (e, await e.plan(c.id));
}

void main() {
  test('Legacy plan JSON remains unchanged and unclassified', () async {
    final (_, legacy) = await environment();
    final json = legacy.toJson();
    final loaded =
        FeedPlan.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
    expect(loaded.productionCategory, isNull);
    expect(loaded.nutritionSnapshot, isNull);
    expect(loaded.toJson(), json);
    expect(json.containsKey('nutritionSnapshot'), isFalse);
  });

  for (final category in ProductionCategory.values) {
    test(
        '${category.name} snapshot round trip preserves all sections and legacy fields',
        () async {
      final (e, original) = await environment();
      final legacy = category == ProductionCategory.dairy
          ? FeedPlan.fromJson(
              Map<String, dynamic>.of(original.toJson())..remove('beefContext'))
          : original;
      final plan = attach(legacy, category);
      final loaded = FeedPlan.fromJson(
          jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>);
      expect(loaded.productionCategory, category);
      expect(loaded.nutritionSnapshot!.response.toJson(), response());
      final withoutSnapshot = Map<String, dynamic>.of(loaded.toJson())
        ..remove('nutritionSnapshot');
      expect(withoutSnapshot, legacy.toJson());
      expect(loaded.matches(e.store.byId(legacy.cattleId)!),
          category == ProductionCategory.beef);
      expect(loaded.nutritionSnapshot!.requirement, response()['requirement']);
      expect(loaded.nutritionSnapshot!.supply, response()['supply']);
      expect(loaded.nutritionSnapshot!.adequacy, response()['adequacy']);
      expect(loaded.nutritionSnapshot!.warnings, response()['warnings']);
      expect(loaded.nutritionSnapshot!.coverage, response()['coverage']);
      expect(loaded.nutritionSnapshot!.assumptions, response()['assumptions']);
      expect(
          loaded.nutritionSnapshot!.defaultsUsed, response()['defaults_used']);
    });
  }

  test(
      'Snapshot freezes caller data deeply and preserves absent vs null fields',
      () {
    final source = response();
    final snapshot = FeedNutritionSnapshot(
        productionCategory: ProductionCategory.dairy,
        response: NutritionResponse.fromJson(source));
    (source['warnings'] as List).clear();
    expect(snapshot.warnings, hasLength(2));
    expect(
        () => (snapshot.coverage as Map)['known'] = [], throwsUnsupportedError);
    expect(() => (snapshot.warnings as List).clear(), throwsUnsupportedError);
    final sparse = FeedNutritionSnapshot(
        productionCategory: ProductionCategory.beef,
        response: NutritionResponse.fromJson({'assumptions': null}));
    expect(FeedNutritionSnapshot.fromJson(sparse.toJson()).response.toJson(),
        {'assumptions': null});
    expect(sparse.requirement, isNull);
    expect(sparse.response.toJson().containsKey('requirement'), isFalse);
  });

  test(
      'Unknown snapshot version, unknown wrapper fields and mismatched category fail closed',
      () {
    final json = FeedNutritionSnapshot(
        productionCategory: ProductionCategory.beef,
        response: NutritionResponse.fromJson({})).toJson();
    for (final invalid in [
      {...json, 'version': 2},
      {...json, 'version': 1.5},
      {...json, 'future_metadata': true},
      {...json, 'productionCategory': null},
      {...json, 'response': []},
      {
        ...json,
        'response': {'production_category': 'dairy'}
      },
    ]) {
      expect(
          () => FeedNutritionSnapshot.fromJson(invalid), throwsFormatException);
    }
  });

  test(
      'Save/reload/backup/restore preserves mixed legacy and v2 history, same-ID conflict rejected',
      () async {
    final (e, legacy) = await environment();
    await e.store.savePlan(legacy);
    final v2 = attach(legacy, ProductionCategory.beef, id: '${legacy.id}-v2');
    await e.store.savePlan(v2);
    final disk = e.disk;
    await e.store.savePlan(FeedPlan.fromJson(v2.toJson()));
    expect(e.store.feedPlans, hasLength(2));
    final conflicting = attach(v2, ProductionCategory.beef, result: {
      'warnings': ['different']
    });
    await expectLater(e.store.savePlan(conflicting), throwsStateError);
    final droppedSnapshot =
        FeedPlan.fromJson({...legacy.toJson(), 'id': v2.id});
    await expectLater(e.store.savePlan(droppedSnapshot), throwsStateError);
    expect(e.disk, disk);
    final reload = FarmStore(read: () async => e.disk, write: (_) async {});
    await reload.load();
    expect(reload.error, isNull);
    expect(reload.feedPlans.map((p) => p.toJson()).toList(),
        [legacy.toJson(), v2.toJson()]);
    final restore = FarmStore(read: () async => null, write: (_) async {});
    await restore.load();
    await restore.restoreBackup(jsonEncode(reload.exportData()));
    expect(restore.feedPlans.last.nutritionSnapshot!.response.toJson(),
        response());
    await restore.remove(legacy.cattleId);
    expect(restore.feedPlans.last.toJson(), v2.toJson());
    expect(restore.byId(legacy.cattleId)!.isActive, isFalse);
  });

  test('Dairy snapshot cannot be attached to a Beef-specific plan context',
      () async {
    final (_, legacy) = await environment();
    expect(
        () => FeedPlanRules.validate(attach(legacy, ProductionCategory.dairy)),
        throwsFormatException);
  });

  test('Write failure preserves both snapshot and memory', () async {
    final (e, legacy) = await environment();
    await e.store.savePlan(legacy);
    final before = e.disk;
    e.fail = true;
    await expectLater(
        e.store.savePlan(attach(legacy, ProductionCategory.beef, id: 'new-v2')),
        throwsStateError);
    expect(e.disk, before);
    expect(e.store.feedPlans.single.nutritionSnapshot, isNull);
  });

  test(
      'Backup round trip keeps Dairy category explicitly without modifying cattle or Beef data',
      () async {
    final (e, legacy) = await environment();
    final cattle = e.store
        .byId(legacy.cattleId)!
        .copyWith(productionCategory: ProductionCategory.dairy);
    final shared = FeedPlan.fromJson(
        Map<String, dynamic>.of(legacy.toJson())..remove('beefContext'));
    final plan = attach(shared, ProductionCategory.dairy);
    final snapshot = FarmSnapshot(cattle: [cattle], feedPlans: [plan]);
    final encoded = FarmBackupCodec.encode(snapshot);
    final decoded = FarmBackupCodec.decode(jsonEncode(encoded));
    expect(
        decoded.feedPlans.single.productionCategory, ProductionCategory.dairy);
    expect(FarmBackupCodec.encode(decoded), encoded);
    expect(
        CattleCodec.encode(decoded.cattle.single), CattleCodec.encode(cattle));
  });

  test(
      'Unsupported persisted snapshot rejects load/restore without writing or replacing state',
      () async {
    final (e, legacy) = await environment();
    await e.store.savePlan(attach(legacy, ProductionCategory.beef));
    final broken = jsonDecode(e.disk!) as Map<String, dynamic>;
    final plan = ((broken['data'] as Map)['feedPlans'] as List).single as Map;
    (plan['nutritionSnapshot'] as Map)['version'] = 99;
    final oldDisk = e.disk;
    await expectLater(
        e.store.restoreBackup(jsonEncode(broken)), throwsFormatException);
    expect(e.disk, oldDisk);
    expect(e.store.feedPlans.single.nutritionSnapshot!.response.toJson(),
        response());
    var writes = 0;
    final failed = FarmStore(
        read: () async => jsonEncode(broken),
        write: (_) async {
          writes++;
        });
    await failed.load();
    expect(failed.error, isNotNull);
    expect(writes, 0);
  });

  for (final version in ['unversioned', '2', '3', '4']) {
    test(
        '$version legacy plans migrate without nutrition snapshots or category inference',
        () {
      final snapshot = FarmBackupCodec.decode(migrationFixtures[version]!);
      final before = snapshot.feedPlans.map((p) => p.toJson()).toList();
      expect(snapshot.feedPlans, isNotEmpty);
      expect(
          snapshot.feedPlans.every((p) =>
              p.productionCategory == null && p.nutritionSnapshot == null),
          isTrue);
      final reloaded =
          FarmBackupCodec.decode(jsonEncode(FarmBackupCodec.encode(snapshot)));
      expect(reloaded.feedPlans.map((p) => p.toJson()).toList(), before);
    });
  }
}
