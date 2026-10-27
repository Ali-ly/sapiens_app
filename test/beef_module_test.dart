import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/data/farm_backup_codec.dart';
import 'package:sapita_app/data/twin_codec.dart';
import 'package:sapita_app/models/beef/beef_feed_context.dart';
import 'package:sapita_app/models/beef/beef_growth.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/farm_command_center.dart';
import 'package:sapita_app/models/feed_plan.dart';
import 'package:sapita_app/models/feed_stock.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/beef_environment.dart';
import 'helpers/migration_fixtures.dart';

Cattle growthCattle(List<double> weights, List<DateTime> dates,
        {double? target, double? near, List<String>? literals}) =>
    Cattle(
        id: 'cow',
        nameOrId: 'Cow',
        gender: 'Jantan',
        ageMonths: 18,
        estimatedWeight: weights.isEmpty ? null : weights.last,
        history: List.generate(
            weights.length,
            (i) => WeightRecord(
                weightKg: weights[i],
                date: dates[i],
                dateText: literals?[i],
                source: 'manual')),
        modules: TwinModules(
            beef: BeefExtension.withRecords([
          if (target != null)
            BeefRecord(
                id: 'target',
                kind: BeefRecordKind.target,
                recordedAt: DateTime.utc(2026),
                occurredAt: DateTime.utc(2026),
                note: 'Target',
                targetKg: target,
                nearKg: near)
        ])));
void main() {
  late BeefEnvironment e;
  setUp(() async {
    e = BeefEnvironment();
    await e.store.load();
  });
  tearDown(() => e.store.dispose());
  test(
      'Purpose, manual phases and target append, persist and reject stale form',
      () async {
    final c = await e.add('Beef');
    await e.setup(c.id);
    for (final phase in BeefPhase.values) {
      await e.store.recordBeef(c.id,
          kind: BeefRecordKind.phase, phase: phase, note: 'Manual');
    }
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.target,
        targetKg: 500,
        nearKg: 470,
        note: 'Target saya');
    final before = e.disk;
    await expectLater(
        e.store.recordBeef(c.id,
            kind: BeefRecordKind.purpose,
            purpose: BeefPurpose.breeding,
            note: 'Stale',
            expectedRevision: 0),
        throwsStateError);
    expect(e.disk, before);
    await e.store.load();
    expect(e.store.byId(c.id)!.modules.beef!.records.length, 9);
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.purpose,
        purpose: BeefPurpose.breeding,
        note: 'Ubah usaha');
    expect(e.store.byId(c.id)!.modules.beef!.purpose, BeefPurpose.breeding);
  });
  test(
      'Beef histories immutable and invalid fields/future date/invalid target fail atomically',
      () async {
    final c = await e.add('Beef');
    await e.setup(c.id);
    final before = e.disk;
    for (final op in [
      () =>
          e.store.recordBeef(c.id, kind: BeefRecordKind.phase, note: 'Missing'),
      () => e.store.recordBeef(c.id,
          kind: BeefRecordKind.target,
          targetKg: 400,
          nearKg: 450,
          note: 'Invalid'),
      () => e.store.recordBeef(c.id,
          kind: BeefRecordKind.phase,
          phase: BeefPhase.calf,
          note: 'Future',
          occurredAt: e.now.add(const Duration(days: 1))),
      () => e.store.recordBeef(c.id,
          kind: BeefRecordKind.purpose,
          purpose: BeefPurpose.fattening,
          phase: BeefPhase.calf,
          note: 'Extra')
    ]) {
      await expectLater(op(), throwsFormatException);
      expect(e.disk, before);
    }
    expect(() => e.store.byId(c.id)!.modules.beef!.records.clear(),
        throwsUnsupportedError);
  });
  test(
      'Failed Beef/stock writes keep state and allow retry, farm guard rejects stale context',
      () async {
    final c = await e.add('Beef');
    final before = e.disk;
    e.fail = true;
    await expectLater(e.setup(c.id), throwsStateError);
    expect(e.disk, before);
    expect(e.store.byId(c.id)!.modules.beef, isNull);
    await expectLater(
        e.store.recordStock(
            feed: 'rumput',
            kind: StockMovement.received,
            kg: 100,
            note: 'Masuk'),
        throwsStateError);
    expect(e.store.feedStock, isEmpty);
    e.fail = false;
    await e.setup(c.id);
    await expectLater(
        e.store.recordBeef(c.id,
            kind: BeefRecordKind.phase,
            phase: BeefPhase.calf,
            note: 'Wrong farm',
            expectedFarmId: 'other'),
        throwsStateError);
    await expectLater(
        e.store.recordStock(
            feed: 'rumput',
            kind: StockMovement.received,
            kg: 100,
            note: 'Wrong farm',
            expectedFarmId: 'other'),
        throwsStateError);
  });
  test(
      'Dairy namespace survives category switches and Beef histories survive inactivity',
      () async {
    await e.store.configureProductionSystems(FarmProductionSystems.both);
    final c = await e.store.saveCattle(Cattle(
        id: '',
        nameOrId: 'Beef',
        gender: 'Jantan',
        ageMonths: 18,
        productionCategory: ProductionCategory.beef,
        modules: const TwinModules(dairy: DairyExtension())));
    final dairy = TwinCodec.encode(c)['modules']['dairy'];
    await e.setup(c.id);
    await e.store.setProductionCategory(c.id, ProductionCategory.dairy,
        reason: 'User changed');
    await expectLater(
        e.store.recordBeef(c.id,
            kind: BeefRecordKind.phase, phase: BeefPhase.calf, note: 'No'),
        throwsStateError);
    expect(TwinCodec.encode(e.store.byId(c.id)!)['modules']['dairy'], dairy);
    await e.store.setProductionCategory(c.id, ProductionCategory.beef,
        reason: 'Restore category');
    final records = e.store.byId(c.id)!.modules.beef!.records;
    await e.store.setCattleStatus(c.id, CattleStatus.sold);
    expect(e.store.activeBeef, isEmpty);
    expect(e.store.byId(c.id)!.modules.beef!.records, records);
    await expectLater(e.setup(c.id), throwsStateError);
    await e.store.setCattleStatus(c.id, CattleStatus.active);
    expect(e.store.activeBeef.length, 1);
  });
  test(
      'ADG uses elapsed fractional days and latest interval, progress/projection deterministic',
      () {
    final c = growthCattle([
      280,
      300,
      315
    ], [
      DateTime.utc(2026, 1, 1),
      DateTime.utc(2026, 1, 11),
      DateTime.utc(2026, 1, 18, 12)
    ], target: 400, near: 380);
    final g = BeefGrowth(c, DateTime.utc(2026, 2));
    expect(g.deltaKg, 15);
    expect(g.intervalDays, 7.5);
    expect(g.adg, 2);
    expect(g.projectedDays, 42.5);
    expect(g.progress, 315 / 400);
    expect(g.harvest, HarvestState.notReady);
  });
  for (final delta in [-10.0, 0.0]) {
    test('ADG $delta preserves decline/flat, no positive projection', () {
      final c = growthCattle([
        300,
        300 + delta
      ], [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 11)
      ], target: 400);
      final g = BeefGrowth(c, DateTime.utc(2026, 2));
      expect(g.adg, delta / 10);
      expect(g.projectedDays, isNull);
    });
  }
  for (final kind in [
    'empty',
    'one',
    'duplicate',
    'decreasing',
    'future',
    'unknownZone'
  ]) {
    test('ADG rejects $kind without editing history', () {
      var weights = [300.0, 320.0];
      var dates = [DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 11)];
      List<String>? literals;
      switch (kind) {
        case 'empty':
          weights = [];
          dates = [];
        case 'one':
          weights = [300];
          dates = [DateTime.utc(2026)];
        case 'duplicate':
          dates = [dates[0], dates[0]];
        case 'decreasing':
          dates = dates.reversed.toList();
        case 'future':
          dates[1] = DateTime.utc(2027);
        case 'unknownZone':
          literals = ['2026-01-01T00:00:00', '2026-01-11T00:00:00'];
      }
      final c = growthCattle(weights, dates, target: 400, literals: literals);
      final g = BeefGrowth(c, DateTime.utc(2026, 2));
      expect(g.adg, isNull);
      expect(g.projectedDays, isNull);
      expect(g.issue, isNotNull);
      expect(c.history.length, weights.length);
    });
  }
  for (final pair in [
    (350.0, HarvestState.notReady),
    (470.0, HarvestState.nearTarget),
    (500.0, HarvestState.evaluate),
    (520.0, HarvestState.evaluate)
  ]) {
    test('Harvest compares user thresholds at ${pair.$1}', () {
      final g = BeefGrowth(
          growthCattle([pair.$1], [DateTime.utc(2026)], target: 500, near: 470),
          DateTime.utc(2026, 2));
      expect(g.harvest, pair.$2);
    });
  }
  for (final badWeight in [0.0, -1.0, double.nan]) {
    test('Growth rejects invalid weight $badWeight', () {
      final c = growthCattle(
          [300, badWeight], [DateTime.utc(2026), DateTime.utc(2026, 1, 10)],
          target: 400);
      final g = BeefGrowth(c, DateTime.utc(2026, 2));
      expect(g.adg, isNull);
      expect(g.harvest, HarvestState.notReady);
    });
  }
  test(
      'No invented near-target band and no projection for target already reached',
      () {
    final g = BeefGrowth(
        growthCattle(
            [490, 499], [DateTime.utc(2026), DateTime.utc(2026, 1, 10)],
            target: 500),
        DateTime.utc(2026, 2));
    expect(g.harvest, HarvestState.notReady);
    final reached = BeefGrowth(
        growthCattle(
            [490, 500], [DateTime.utc(2026), DateTime.utc(2026, 1, 10)],
            target: 500),
        DateTime.utc(2026, 2));
    expect(reached.projectedDays, isNull);
  });
  test(
      'Feeding guard respects latest manual pregnancy correction without inventing calving',
      () async {
    final c = await e.add('Induk', gender: 'Betina');
    await e.setup(c.id, purpose: BeefPurpose.breeding);
    await e.store.recordBeef(c.id, kind: BeefRecordKind.service, note: 'IB');
    final service = e.store.byId(c.id)!.modules.beef!.records.last;
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.pregnancy,
        relatedId: service.id,
        pregnancy: PregnancyResult.positive,
        note: 'Pemeriksaan');
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.purpose,
        purpose: BeefPurpose.fattening,
        note: 'Ubah tujuan');
    expect(BeefFeedContext.limitation(e.store.byId(c.id)!, 'penggemukan'),
        contains('positif'));
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.purpose,
        purpose: BeefPurpose.breeding,
        note: 'Koreksi data');
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.pregnancy,
        relatedId: service.id,
        pregnancy: PregnancyResult.negative,
        note: 'Koreksi manual');
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.purpose,
        purpose: BeefPurpose.fattening,
        note: 'Tujuan pengguna');
    expect(
        BeefFeedContext.limitation(e.store.byId(c.id)!, 'penggemukan'), isNull);
    expect(
        e.store
            .byId(c.id)!
            .modules
            .beef!
            .records
            .where((r) => r.kind == BeefRecordKind.calving),
        isEmpty);
  });
  test(
      'Limited Beef plan records context; revisions invalidate old plans and block stale save',
      () async {
    final c = await e.add('Beef');
    await e.setup(c.id);
    final p = await e.plan(c.id);
    expect(p.beefContext!.matches(e.store.byId(c.id)!), isTrue);
    await e.store.savePlan(p);
    expect(e.store.planReady(e.store.byId(c.id)!), isTrue);
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.phase, phase: BeefPhase.finishing, note: 'Manual');
    expect(e.store.planReady(e.store.byId(c.id)!), isFalse);
    expect(BeefFeedContext.limitation(e.store.byId(c.id)!, 'pemeliharaan'),
        isNotNull);
    final stale = FeedPlan.fromJson({...p.toJson(), 'id': 'other'});
    await expectLater(e.store.savePlan(stale), throwsStateError);
    expect(e.store.feedPlans.length, 1);
  });
  test(
      'Legacy Beef plan retained but excluded, eligible 7/30 demand and shortage are explicit',
      () async {
    final a = await e.add('A');
    await e.setup(a.id);
    final p = await e.plan(a.id);
    await e.store.savePlan(p);
    final b = await e.add('B');
    await e.setup(b.id);
    await e.store.recordStock(
        feed: 'rumput', kind: StockMovement.received, kg: 100, note: 'Masuk');
    final d = e.store.beefDemand(7);
    expect(d.total, 2);
    expect(d.eligible, 1);
    expect(d.excluded, ['B']);
    final daily = p.portions.firstWhere((p) => p.key == 'rumput').asFedKg;
    expect(d.requiredKg('rumput'), daily * 7);
    expect(e.store.beefDemand(30).requiredKg('rumput'), daily * 30);
    expect(d.daysRemaining('rumput'), 100 / daily);
    expect(d.shortageKg('rumput'), (daily * 7 - 100).clamp(0, double.infinity));
    final json = p.toJson()..remove('beefContext');
    json['id'] = 'legacy';
    // Legacy plans can be imported as history but cannot be newly activated.
    final backup = e.store.exportData();
    (backup['data']['feedPlans'] as List).add(json);
    await e.store.restoreBackup(jsonEncode(backup));
    expect(e.store.feedPlans.length, 2);
    expect(e.store.beefDemand().eligible, 0);
    expect(
        e.store.commandCenter.actions
            .firstWhere((action) => action.cattle.id == a.id)
            .kind,
        FarmActionKind.reviewFeedContext);
  });
  test(
      'Stock ledger in/use/correction, negative/NaN/unit/unknown ingredient reject without data loss',
      () async {
    await e.store.recordStock(
        feed: 'rumput', kind: StockMovement.received, kg: 100, note: 'Beli');
    await e.store.recordStock(
        feed: 'rumput', kind: StockMovement.used, kg: 20, note: 'Diberikan');
    await e.store.recordStock(
        feed: 'rumput',
        kind: StockMovement.correction,
        kg: -5,
        note: 'Timbang ulang');
    expect(StockEntry.balances(e.store.feedStock)['rumput'], 75);
    final before = e.disk;
    for (final (feed, kind, kg) in [
      ('rumput', StockMovement.used, 76.0),
      ('rumput', StockMovement.received, -1.0),
      ('dedak', StockMovement.received, double.nan),
      ('unknown', StockMovement.received, 1.0),
      ('rumput', StockMovement.correction, 0.0)
    ]) {
      await expectLater(
          e.store.recordStock(feed: feed, kind: kind, kg: kg, note: 'Invalid'),
          throwsFormatException);
      expect(e.disk, before);
    }
    await e.store.load();
    expect(e.store.feedStock.length, 3);
  });
  test(
      'Future-dated stock stays visible in ledger but is excluded from current supply',
      () async {
    final now = e.now;
    e.now = e.now.add(const Duration(days: 1));
    await e.store.recordStock(
        feed: 'rumput',
        kind: StockMovement.received,
        kg: 100,
        note: 'Future clock');
    e.now = now;
    expect(e.store.feedStock.length, 1);
    expect(e.store.beefDemand().stock['rumput'], 0);
  });
  test(
      'Concurrent stock use validates latest balance; stale revision cannot overwrite',
      () async {
    await e.store.recordStock(
        feed: 'rumput', kind: StockMovement.received, kg: 10, note: 'Masuk');
    final first = e.store.recordStock(
        feed: 'rumput', kind: StockMovement.used, kg: 8, note: 'Pertama');
    final second = e.store.recordStock(
        feed: 'rumput', kind: StockMovement.used, kg: 8, note: 'Kedua');
    await first;
    await expectLater(second, throwsFormatException);
    expect(StockEntry.balances(e.store.feedStock)['rumput'], 2);
    await expectLater(
        e.store.recordStock(
            feed: 'rumput',
            kind: StockMovement.received,
            kg: 5,
            note: 'Stale',
            expectedRevision: 1),
        throwsStateError);
  });
  test(
      'Future or unknown-zone Beef weight cannot become operational stock demand',
      () async {
    final c = await e.add('Temporal');
    await e.setup(c.id);
    final originalNow = e.now;
    e.now = e.now.add(const Duration(days: 1));
    final p = await e.plan(c.id);
    await e.store.savePlan(p);
    e.now = originalNow;
    expect(e.store.beefDemand().eligible, 0);
    expect(e.store.needsCheck(e.store.byId(c.id)!), isTrue);
    e.now = e.now.add(const Duration(days: 1));
    final j = e.store.exportData();
    final cow = j['data']['cattle'][0];
    cow['history'][0]['date'] = '2026-10-27T10:00:00';
    j['data']['feedPlans'][0]['weightDate'] = '2026-10-27T10:00:00';
    await e.store.restoreBackup(jsonEncode(j));
    expect(e.store.beefDemand().eligible, 0);
  });
  test(
      'Command Center routes unsupported Beef feeding to review, not a false ration task',
      () async {
    final c = await e.add('Breeding', gender: 'Betina');
    await e.setup(c.id, purpose: BeefPurpose.breeding);
    await e.store.recordWeight(c.id, weightKg: 350, source: 'manual');
    expect(e.store.commandCenter.readyCount, 0);
    expect(e.store.commandCenter.actions.single.kind,
        FarmActionKind.reviewFeedContext);
  });
  test(
      'Stock demand excludes inactive, Dairy, stale and independent bulk groups',
      () async {
    final a = await e.add('A');
    await e.setup(a.id);
    await e.store.savePlan(await e.plan(a.id));
    final dairy = await e.add('Dairy', category: ProductionCategory.dairy);
    expect(dairy.isActive, isTrue);
    final group = await e.store.createGroup('Independent',
        headCount: 100, averageWeightKg: 350, target: 'penggemukan', notes: '');
    expect(group.headCount, 100);
    expect(e.store.beefDemand().total, 1);
    expect(e.store.beefDemand().eligible, 1);
    await e.store.setCattleStatus(a.id, CattleStatus.sold);
    expect(e.store.beefDemand().total, 0);
    await e.store.setCattleStatus(a.id, CattleStatus.active);
    e.now = e.now.add(const Duration(days: 8));
    expect(e.store.beefDemand().eligible, 0);
  });
  test(
      'Breeding, pregnancy, calving link existing calf atomically and retain all facts',
      () async {
    final dam = await e.add('Dam', gender: 'Betina'),
        sire = await e.add('Sire'),
        calf = await e.add('Calf');
    await e.setup(dam.id, purpose: BeefPurpose.breeding);
    await e.store.recordBeef(dam.id,
        kind: BeefRecordKind.service, sireId: sire.id, note: 'IB pengguna');
    final service = e.store.byId(dam.id)!.modules.beef!.records.last;
    await e.store.recordBeef(dam.id,
        kind: BeefRecordKind.pregnancy,
        relatedId: service.id,
        pregnancy: PregnancyResult.positive,
        note: 'Pemeriksaan manual');
    final check = e.store.byId(dam.id)!.modules.beef!.records.last;
    await e.store.recordBeef(dam.id,
        kind: BeefRecordKind.calving,
        relatedId: check.id,
        calfId: calf.id,
        note: 'Kelahiran dicatat');
    expect(e.store.byId(calf.id)!.core.references.damId, dam.id);
    expect(e.store.byId(calf.id)!.core.references.sireId, sire.id);
    expect(e.store.byId(calf.id)!.ageMonths, 18);
    final before = e.disk;
    await expectLater(
        e.store.recordBeef(dam.id,
            kind: BeefRecordKind.calving,
            relatedId: check.id,
            note: 'Duplicate'),
        throwsFormatException);
    expect(e.disk, before);
    await e.store.load();
    expect(e.store.byId(dam.id)!.modules.beef!.records.length, 5);
  });
  test(
      'Reproduction rejects missing links, wrong gender, negative/superseded pregnancy and cycles',
      () async {
    final dam = await e.add('Dam', gender: 'Betina'),
        male = await e.add('Male');
    await e.setup(dam.id, purpose: BeefPurpose.breeding);
    await e.setup(male.id, purpose: BeefPurpose.breeding);
    await expectLater(
        e.store
            .recordBeef(male.id, kind: BeefRecordKind.service, note: 'Invalid'),
        throwsFormatException);
    await expectLater(
        e.store.recordBeef(dam.id,
            kind: BeefRecordKind.service, sireId: dam.id, note: 'Invalid'),
        throwsFormatException);
    await expectLater(
        e.store.recordBeef(dam.id,
            kind: BeefRecordKind.pregnancy,
            relatedId: 'missing',
            pregnancy: PregnancyResult.positive,
            note: 'Invalid'),
        throwsFormatException);
    await e.store.recordBeef(dam.id,
        kind: BeefRecordKind.service, sireId: male.id, note: 'IB');
    final service = e.store.byId(dam.id)!.modules.beef!.records.last;
    await e.store.recordBeef(dam.id,
        kind: BeefRecordKind.pregnancy,
        relatedId: service.id,
        pregnancy: PregnancyResult.positive,
        note: 'Positive');
    final positive = e.store.byId(dam.id)!.modules.beef!.records.last;
    await e.store.recordBeef(dam.id,
        kind: BeefRecordKind.pregnancy,
        relatedId: service.id,
        pregnancy: PregnancyResult.negative,
        note: 'Correction');
    final negative = e.store.byId(dam.id)!.modules.beef!.records.last;
    for (final related in [positive.id, negative.id]) {
      await expectLater(
          e.store.recordBeef(dam.id,
              kind: BeefRecordKind.calving,
              relatedId: related,
              note: 'Invalid'),
          throwsFormatException);
    }
    await e.store.recordBeef(dam.id,
        kind: BeefRecordKind.pregnancy,
        relatedId: service.id,
        pregnancy: PregnancyResult.positive,
        note: 'New check');
    final check = e.store.byId(dam.id)!.modules.beef!.records.last;
    final before = e.disk;
    await expectLater(
        e.store.recordBeef(dam.id,
            kind: BeefRecordKind.calving,
            relatedId: check.id,
            calfId: male.id,
            note: 'Would cycle'),
        throwsFormatException);
    expect(e.disk, before);
  });
  test(
      'Old schema5 foundation2/module1 upgrades once, unknown new version fails closed',
      () async {
    var disk = migrationFixtures['5']!;
    var writes = 0;
    final store = FarmStore(
        read: () async => disk,
        write: (r) async {
          writes++;
          disk = r;
        });
    addTearDown(store.dispose);
    await store.load();
    expect(store.error, isNull);
    expect(writes, 1);
    expect(jsonDecode(disk)['data']['foundation']['version'], 3);
    expect(
        jsonDecode(disk)['data']['cattle'][0]['foundation']['modules']['dairy'],
        {'version': 2, 'records': [], 'milk': []});
    await store.load();
    expect(writes, 1);
    final before = disk;
    final j = jsonDecode(disk);
    j['data']['foundation']['version'] = 999;
    disk = jsonEncode(j);
    final invalid = disk;
    await store.load();
    expect(store.error, isNotNull);
    expect(writes, 1);
    expect(disk, invalid);
    expect(store.allCattle.length, 1);
    await expectLater(store.settings('No', 'No', 7), throwsStateError);
    expect(writes, 1);
    await store.restoreBackup(before);
    expect(store.error, isNull);
  });
  test(
      'Failed foundation upgrade does not publish or overwrite source, deterministic retry',
      () async {
    var disk = migrationFixtures['5']!;
    var fail = true;
    final store = FarmStore(
        read: () async => disk,
        write: (r) async {
          if (fail) throw StateError('disk');
          disk = r;
        });
    addTearDown(store.dispose);
    await store.load();
    expect(store.error, isNotNull);
    expect(store.allCattle, isEmpty);
    expect(disk, migrationFixtures['5']);
    fail = false;
    await store.load();
    expect(store.error, isNull);
    expect(
        jsonDecode(disk),
        FarmBackupCodec.encode(
            FarmBackupCodec.decode(migrationFixtures['5']!)));
  });
  for (final issue in [
    'moduleVersion',
    'recordField',
    'stockUnit',
    'stockField',
    'duplicateId'
  ]) {
    test('Phase4 import rejects $issue and preserves existing state', () async {
      final c = await e.add('Cow');
      await e.setup(c.id);
      await e.store.recordStock(
          feed: 'rumput', kind: StockMovement.received, kg: 10, note: 'Masuk');
      final before = e.disk;
      final j = e.store.exportData();
      final module = j['data']['cattle'][0]['foundation']['modules']['beef'];
      final stock = j['data']['foundation']['feedStock'][0];
      switch (issue) {
        case 'moduleVersion':
          module['version'] = 999;
        case 'recordField':
          module['records'][0]['unknown'] = true;
        case 'stockUnit':
          stock['unit'] = 'ton';
        case 'stockField':
          stock['cost'] = 100;
        case 'duplicateId':
          stock['id'] = module['records'][0]['id'];
      }
      await expectLater(
          e.store.restoreBackup(jsonEncode(j)), throwsFormatException);
      expect(e.disk, before);
    });
  }
}
