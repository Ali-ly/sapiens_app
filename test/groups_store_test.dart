import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sapita_app/data/farm_backup_codec.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/group_feed_plan.dart';
import 'package:sapita_app/models/livestock_group.dart';
import 'package:sapita_app/services/group_feed_service.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/backup_fixture.dart';
import 'helpers/feed_fixture.dart';

void main() {
  late FarmStore store;
  late DateTime now;
  String? disk;
  var fail = false;
  setUp(() async {
    now = DateTime.utc(2020, 1, 1);
    disk = null;
    fail = false;
    store = FarmStore(
        now: () => now,
        read: () async => disk,
        write: (value) async {
          if (fail) {
            throw StateError('disk full');
          }
          disk = value;
        });
    await store.load();
  });
  tearDown(() => store.dispose());
  Future<LivestockGroup> group({int count = 100, double? weight = 350}) =>
      store.createGroup('Kandang A',
          headCount: count, averageWeightKg: weight, target: 'penggemukan');
  Future<GroupFeedPlan> calculate(LivestockGroup g) async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          ...readFeedResponse(),
          'weight_kg': g.averageWeightKg,
          'target': g.target
        }),
        200));
    try {
      return await GroupFeedService.calculate(
          group: g,
          availableFeeds: ['rumput', 'jerami', 'dedak'],
          client: client);
    } finally {
      client.close();
    }
  }

  Future<void> update(LivestockGroup g,
          {int? count, double? weight, String? target, String? name}) =>
      store.updateGroup(g.id,
          name: name ?? g.name,
          headCount: count ?? g.headCount,
          averageWeightKg: weight ?? g.averageWeightKg,
          target: target ?? g.target,
          notes: 'Dicatat');

  test('Bulk groups persist without individual profiles or membership',
      () async {
    final g = await group();
    expect(store.cattle, isEmpty);
    expect(g.headCount, 100);
    expect(g.averageWeightKg, 350);
    expect(g.target, 'penggemukan');
    expect(g.history, hasLength(1));
    expect(store.exportData()['schemaVersion'], 5);
    final loaded =
        FarmStore(now: () => now, read: () async => disk, write: (_) async {});
    await loaded.load();
    expect(loaded.error, isNull);
    expect(loaded.groups.single.headCount, 100);
    expect(() => loaded.groups.single.history.clear(), throwsUnsupportedError);
    loaded.dispose();
  });

  test('API uses average weight once and quantities are multiplied per head',
      () async {
    final g = await group();
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(jsonDecode(request.body), {
        'weight': 350.0,
        'target': 'penggemukan',
        'available_feeds': ['rumput', 'jerami', 'dedak']
      });
      return http.Response(jsonEncode(readFeedResponse()), 200);
    });
    final plan = await GroupFeedService.calculate(
        group: g,
        availableFeeds: ['rumput', 'jerami', 'dedak'],
        client: client);
    expect(calls, 1);
    expect(plan.freshKgPerHead, closeTo(27.3, .001));
    expect(plan.totalFreshKg, closeTo(2730, .001));
    expect(plan.groupPortions.first.asFedKg, 2200);
    expect(plan.groupPortions.first.dryMatterKg, 394);
    await store.saveGroupPlan(plan);
    expect(store.groupDailyFeedTotals['rumput'], 2200);
    expect(store.dailyFeedTotals, isEmpty);
    expect(store.cattle, isEmpty);
    client.close();
  });

  test(
      'History records all bulk edits and current values derive from the last record',
      () async {
    final g = await group();
    now = now.add(const Duration(days: 1));
    await update(g, count: 90, weight: 370, target: 'pemeliharaan');
    final changed = store.groupById(g.id)!;
    expect(changed.history.first.headCount, 100);
    expect(changed.headCount, 90);
    expect(changed.averageWeightKg, 370);
    expect(changed.history, hasLength(2));
    expect(changed.current.recordedAt, now);
    expect(FarmBackupCodec.decode(disk!).groups.single.history, hasLength(2));
  });

  for (final field in ['count', 'weight', 'target']) {
    test(
        'Changing $field excludes the old group plan from totals and rejects stale results',
        () async {
      final g = await group();
      final old = await calculate(g);
      await store.saveGroupPlan(old);
      await update(g,
          count: field == 'count' ? 50 : null,
          weight: field == 'weight' ? 360 : null,
          target: field == 'target' ? 'pertumbuhan' : null);
      expect(store.groupDailyFeedTotals, isEmpty);
      expect(store.groupPlanReady(store.groupById(g.id)!), isFalse);
      await store
          .saveGroupPlan(old); // Identical retry does not create new history.
      final staleNew =
          GroupFeedPlan.fromJson({...old.toJson(), 'id': 'new-stale-plan'});
      await expectLater(store.saveGroupPlan(staleNew), throwsStateError);
      expect(store.groupFeedPlans, hasLength(1));
    });
  }

  test(
      'Metadata edits keep quantitative plans valid while recording the rename',
      () async {
    final g = await group();
    await store.saveGroupPlan(await calculate(g));
    await update(g, name: 'Kandang Utara');
    expect(store.groupPlanReady(store.groupById(g.id)!), isTrue);
    expect(store.groupById(g.id)!.history.first.name, 'Kandang A');
  });

  test('Changing quantities back does not accidentally revive an older plan',
      () async {
    final g = await group();
    await store.saveGroupPlan(await calculate(g));
    await update(g, count: 80);
    await update(store.groupById(g.id)!, count: 100);
    expect(store.groupPlanReady(store.groupById(g.id)!), isFalse);
  });

  test(
      'Zero count and missing averages are allowed records but cannot request feed',
      () async {
    final g = await group(count: 0, weight: null);
    expect(g.canCalculateFeed, isFalse);
    await expectLater(
        GroupFeedService.calculate(group: g, availableFeeds: ['rumput']),
        throwsFormatException);
    await store.updateGroup(g.id,
        name: g.name,
        headCount: 10,
        averageWeightKg: null,
        target: g.target,
        notes: '');
    expect(store.groupById(g.id)!.canCalculateFeed, isFalse);
  });

  test(
      'Archives retain counted livestock and history without requiring individual moves',
      () async {
    final g = await group();
    await store.saveGroupPlan(await calculate(g));
    await store.archiveGroup(g.id);
    expect(store.groups.single.headCount, 100);
    expect(store.groups.single.current.source, 'archive');
    expect(store.groupHeadCount, 0);
    expect(store.groupDailyFeedTotals, isEmpty);
    await store.restoreGroup(g.id);
    expect(store.groupHeadCount, 100);
    expect(store.groups.single.history, hasLength(3));
  });

  test(
      'Concurrent edits retain both observations and failed writes do not change history',
      () async {
    final g = await group();
    await Future.wait([update(g, count: 80), update(g, count: 70)]);
    expect(store.groups.single.history, hasLength(3));
    expect(store.groups.single.headCount, 70);
    final before = disk;
    fail = true;
    await expectLater(update(store.groups.single, count: 60), throwsStateError);
    expect(disk, before);
    expect(store.groups.single.history, hasLength(3));
    fail = false;
    await update(store.groups.single, count: 60);
    expect(store.groups.single.headCount, 60);
  });

  test(
      'Individual edits, deletion, settings and examples do not change bulk counts',
      () async {
    final g = await group();
    final c = await store
        .saveCattle(Cattle(nameOrId: 'Budi', gender: 'Jantan', ageMonths: 18));
    await store.recordWeight(c.id, weightKg: 500, source: 'manual');
    await store.remove(c.id);
    await store.settings('Ali', 'Farm', 14);
    await store.addExamples();
    await store.removeExamples();
    expect(store.groupById(g.id)!.headCount, 100);
    expect(store.groupById(g.id)!.averageWeightKg, 350);
    expect(store.groups.single.history, hasLength(1));
  });

  test('Invalid bulk values and duplicate names are rejected atomically',
      () async {
    final g = await group();
    await expectLater(
        store.createGroup('KANDANG A', headCount: 1), throwsFormatException);
    await expectLater(update(g, count: -1), throwsFormatException);
    await expectLater(update(g, weight: double.nan), throwsFormatException);
    expect(store.groups.single.history, hasLength(1));
  });

  test(
      'Backup preserves quantitative history, group plans and old schema 2 profiles',
      () async {
    final g = await group();
    await store.saveGroupPlan(await calculate(g));
    await update(g, count: 90);
    final backup = jsonEncode(store.exportData());
    await store.restoreBackup(backup);
    expect(store.groups.single.history, hasLength(2));
    expect(store.groupFeedPlans, hasLength(1));
    expect(store.groupDailyFeedTotals, isEmpty);
    final legacy = legacySchema4(store.exportData());
    legacy['schemaVersion'] = 2;
    legacy.remove('groups');
    legacy.remove('legacyMemberships');
    legacy.remove('groupFeedPlans');
    final old = FarmBackupCodec.decode(jsonEncode(legacy));
    expect(old.groups, isEmpty);
    final invalid = store.exportData();
    final encoded = (backupPayload(invalid)['groups'] as List).single
        as Map<String, dynamic>;
    final record = (encoded['history'] as List).last as Map<String, dynamic>;
    record['headCount'] = -3;
    await expectLater(
        store.restoreBackup(jsonEncode(invalid)), throwsFormatException);
    expect(store.groups.single.headCount, 90);
  });

  test(
      'Schema 3 membership is migrated once and retained as read-only legacy data',
      () async {
    final c = await store.saveCattle(Cattle(
        nameOrId: 'Budi',
        gender: 'Jantan',
        ageMonths: 18,
        estimatedWeight: 350,
        history: [WeightRecord(weightKg: 350, date: now)]));
    final data = legacySchema4(store.exportData())..['schemaVersion'] = 3;
    data.remove('groupFeedPlans');
    data.remove('legacyMemberships');
    data['groups'] = [
      {
        'id': 'old-group',
        'name': 'Kandang lama',
        'notes': 'Catatan',
        'createdAt': now.toIso8601String(),
        'archivedAt': null
      }
    ];
    data['memberships'] = [
      {
        'id': 'old-stay',
        'groupId': 'old-group',
        'cattleId': c.id,
        'joinedAt': now.toIso8601String(),
        'leftAt': null
      }
    ];
    final migrated = FarmBackupCodec.decode(jsonEncode(data), migratedAt: now);
    expect(migrated.groups.single.headCount, 1);
    expect(migrated.groups.single.averageWeightKg, 350);
    expect(migrated.groups.single.current.source, 'migration');
    expect(migrated.legacyMemberships, hasLength(1));
    await store.restoreBackup(jsonEncode(FarmBackupCodec.encode(migrated)));
    await store.remove(c.id);
    final roundTrip = FarmBackupCodec.decode(jsonEncode(store.exportData()));
    expect(roundTrip.groups.single.headCount, 1);
    expect(roundTrip.legacyMemberships, hasLength(1));
    expect(roundTrip.cattle.single.id, c.id);
    expect(roundTrip.cattle.single.status, CattleStatus.archived);
  });

  test('Bad API results and network rejection never create a fake group plan',
      () async {
    final g = await group();
    final client = MockClient((_) async => http.Response(
        jsonEncode({...readFeedResponse(), 'weight_kg': 999}), 200));
    await expectLater(
        GroupFeedService.calculate(
            group: g,
            availableFeeds: ['rumput', 'jerami', 'dedak'],
            client: client),
        throwsFormatException);
    expect(store.groupFeedPlans, isEmpty);
    client.close();
  });
}
