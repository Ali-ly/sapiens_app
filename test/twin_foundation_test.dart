import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapita_app/data/farm_backup_codec.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_plan.dart';
import 'package:sapita_app/models/group_feed_plan.dart';
import 'package:sapita_app/models/selected_image.dart';
import 'package:sapita_app/screens/cattle/cattle_list_screen.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/backup_fixture.dart';
import 'helpers/test_app.dart';

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200,
      scrollable: find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .last,
      maxScrolls: 40);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  late FarmStore store;
  String? disk;
  var writes = 0;
  var failWrites = false;
  final now = DateTime.utc(2026, 10, 25);
  FarmStore openStore() => FarmStore(
      now: () => now,
      read: () async => disk,
      write: (raw) async {
        if (failWrites) throw StateError('disk full');
        writes++;
        disk = raw;
      });
  setUp(() async {
    disk = null;
    writes = 0;
    failWrites = false;
    store = openStore();
    await store.load();
  });
  tearDown(() => store.dispose());
  Future<Cattle> add(String name, {ProductionCategory? category}) =>
      store.saveCattle(Cattle(
          nameOrId: name,
          gender: 'Betina',
          ageMonths: 24,
          productionCategory: category));
  SelectedImage photo(String name) {
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jV9kAAAAASUVORK5CYII=');
    return SelectedImage(file: XFile.fromData(bytes, name: name), bytes: bytes);
  }

  FeedPlan plan(Cattle c, {String id = 'plan-1'}) => FeedPlan(
      id: id,
      cattleId: c.id,
      cattleName: c.nameOrId,
      weightKg: c.estimatedWeight!,
      ageMonths: c.ageMonths,
      gender: c.gender,
      bodyCondition: 'Sedang',
      target: 'pemeliharaan',
      availableFeeds: ['rumput'],
      createdAt: now,
      weightDate: c.history.last.date,
      portions: [const FeedPortion(key: 'rumput', asFedKg: 20)]);
  Map<String, dynamic> backup() =>
      jsonDecode(jsonEncode(store.exportData())) as Map<String, dynamic>;
  Map<String, dynamic> twin(Map<String, dynamic> data) =>
      ((backupPayload(data)['cattle'] as List).first
          as Map<String, dynamic>)['foundation'] as Map<String, dynamic>;

  for (final systems in FarmProductionSystems.values) {
    test('${systems.name} farm round-trips and assigns new cattle explicitly',
        () async {
      await store.configureProductionSystems(systems);
      if (systems == FarmProductionSystems.both) {
        await expectLater(add('No category'), throwsStateError);
        await add('Beef', category: ProductionCategory.beef);
        await add('Dairy', category: ProductionCategory.dairy);
      } else {
        final c = await add('First');
        expect(c.productionCategory, systems.singleCategory);
        final other = systems == FarmProductionSystems.beef
            ? ProductionCategory.dairy
            : ProductionCategory.beef;
        await expectLater(add('Wrong', category: other), throwsFormatException);
      }
      final decoded = FarmBackupCodec.decode(disk!);
      expect(decoded.productionSystems, systems);
      expect(
          decoded.cattle.map((c) => c.productionCategory),
          systems == FarmProductionSystems.both
              ? [ProductionCategory.beef, ProductionCategory.dairy]
              : [systems.singleCategory]);
    });
  }

  test(
      'Legacy schema 4 stays unassigned with durable IDs and no invented events',
      () async {
    final c = await add('Legacy');
    final old = legacySchema4(backup());
    old.remove('foundation');
    final oldCattle = (old['cattle'] as List).first as Map;
    oldCattle.remove('foundation');
    oldCattle['weight'] = 300.0;
    oldCattle['history'] = [
      {'weight': 300.0, 'date': now.toIso8601String(), 'source': 'manual'}
    ];
    oldCattle['images'] = [
      {'name': 'legacy.png', 'bytes': base64Encode(photo('legacy.png').bytes)}
    ];
    disk = jsonEncode(old);
    final before = writes;
    await store.load();
    expect(writes, before + 1);
    expect(store.productionSystems, isNull);
    expect(store.byId(c.id)!.history.single.id, isNotNull);
    expect(store.byId(c.id)!.history.single.weightKg, 300);
    expect(store.byId(c.id)!.images, hasLength(1));
    expect(store.byId(c.id)!.images.single.name, 'legacy.png');
    expect(store.byId(c.id)!.core.photos.history, isEmpty);
    expect(store.byId(c.id)!.productionCategory, isNull);
    await store.configureProductionSystems(FarmProductionSystems.beef);
    expect(store.byId(c.id)!.productionCategory, isNull);
    expect(store.byId(c.id)!.core.timeline, isEmpty);
    final upgraded = backupPayload(
        FarmBackupCodec.encode(FarmBackupCodec.decode(jsonEncode(old))));
    final row = (upgraded['cattle'] as List).single as Map;
    expect(row['weight'], oldCattle['weight']);
    expect((row['history'] as List).single['date'],
        (oldCattle['history'] as List).single['date']);
    expect((row['images'] as List).single['bytes'],
        (oldCattle['images'] as List).single['bytes']);
  });

  test('Multiple weights and photos append; all components round-trip',
      () async {
    await store.configureProductionSystems(FarmProductionSystems.both);
    final dam = await add('Dam', category: ProductionCategory.dairy);
    final c = await add('Twin', category: ProductionCategory.beef);
    await store.updateReferences(
        c.id, TwinReferences(damId: dam.id, externalIds: {'earTag': 'ABC'}));
    await store.recordWeight(c.id,
        weightKg: 300, source: 'ai', images: [photo('first.png')]);
    await store.recordWeight(c.id,
        weightKg: 310, source: 'manual', images: [photo('second.png')]);
    await store.addPhotos(c.id, [photo('third.png')]);
    await store.recordLifeStage(c.id, LifeStage.adult,
        note: 'Dicatat peternak');
    await store.recordHealth(c.id,
        kind: HealthKind.vaccination,
        occurredAt: now,
        note: 'Catatan vaksin',
        nextDueAt: now.add(const Duration(days: 30)));
    await store.recordHealth(c.id,
        kind: HealthKind.preventiveCare,
        occurredAt: now,
        note: 'Pemeriksaan rutin');
    final decoded = FarmBackupCodec.decode(disk!).cattle.last;
    expect(decoded.history.map((r) => r.weightKg), [300, 310]);
    expect(decoded.history.map((r) => r.id).toSet(), hasLength(2));
    expect(decoded.images, hasLength(3));
    expect(decoded.core.photos.history.map((r) => r.imageIndex), [0, 1, 2]);
    expect(decoded.core.photos.history.first.weightRecordId,
        decoded.history.first.id);
    expect(decoded.core.lifecycle.stage, LifeStage.adult);
    expect(decoded.core.health.map((r) => r.kind),
        [HealthKind.vaccination, HealthKind.preventiveCare]);
    expect(decoded.core.references.damId, dam.id);
    expect(decoded.core.references.externalIds['earTag'], 'ABC');
    expect(decoded.core.timeline, hasLength(8));
    expect(() => decoded.core.health.clear(), throwsUnsupportedError);
    expect(() => decoded.core.timeline.clear(), throwsUnsupportedError);
    expect(() => decoded.core.references.externalIds.clear(),
        throwsUnsupportedError);
    expect(FarmBackupCodec.encode(FarmBackupCodec.decode(disk!)),
        store.exportData()..remove('exportedAt'));
  });

  for (final status
      in CattleStatus.values.where((s) => s != CattleStatus.active)) {
    test(
        '${status.name} retains Twin and feed history while excluding operations',
        () async {
      final c = await add('Twin');
      final weighed =
          await store.recordWeight(c.id, weightKg: 300, source: 'manual');
      final savedPlan = plan(weighed);
      await store.savePlan(savedPlan);
      await store.setCattleStatus(c.id, status, note: 'Dicatat');
      expect(store.cattle, isEmpty);
      expect(store.byId(c.id)!.status, status);
      expect(store.byId(c.id)!.history, hasLength(1));
      expect(store.feedPlans.single.id, savedPlan.id);
      expect(store.dailyFeedTotals, isEmpty);
      expect(store.commandCenter.cattleCount, 0);
      expect(store.commandCenter.actions, isEmpty);
      expect(store.planReady(store.byId(c.id)!), isFalse);
      expect(FarmBackupCodec.decode(disk!).cattle.single.status, status);
      await expectLater(
          store.recordWeight(c.id, weightKg: 310, source: 'manual'),
          throwsStateError);
      await expectLater(
          store.savePlan(plan(weighed, id: 'new-plan')), throwsStateError);
      await store.savePlan(
          savedPlan); // identical persisted history is an idempotent retry
      final other = await add('Other');
      await store.settings('Peternak', 'Farm', 7);
      expect(store.allCattle, hasLength(2));
      expect(store.byId(c.id), isNotNull);
      expect(store.byId(other.id), isNotNull);
      await store.setCattleStatus(c.id, CattleStatus.active,
          note: 'Koreksi status');
      expect(store.cattle, hasLength(2));
      expect(store.byId(c.id)!.core.lifecycle.statuses.map((r) => r.status),
          [status, CattleStatus.active]);
    });
  }

  test(
      'Identical clocks across concurrent writes and reloads never reuse generated IDs',
      () async {
    final first = await Future.wait([add('A'), add('B')]);
    await store.recordWeight(first.first.id, weightKg: 300, source: 'manual');
    await store.createGroup('A', headCount: 2);
    final before = backup();
    store.dispose();
    store = openStore();
    await store.load();
    final c = await add('C');
    await store.recordWeight(c.id, weightKg: 301, source: 'manual');
    await store.createGroup('B', headCount: 3);
    expect(store.allCattle, hasLength(3));
    expect(store.groups, hasLength(2));
    expect(store.allCattle.take(2).map((c) => c.id), first.map((c) => c.id));
    expect((backupPayload(before)['cattle'] as List).first['history'],
        (backupPayload(backup())['cattle'] as List).first['history']);
    final ids = [
      ...store.allCattle.map((c) => c.id),
      ...store.allCattle.expand((c) => c.history).map((r) => r.id!),
      ...store.allCattle.expand((c) => c.core.timeline).map((r) => r.id),
      ...store.groups.map((g) => g.id),
      ...store.groups.expand((g) => g.history).map((r) => r.id),
    ];
    expect(ids.toSet().length, ids.length);
  });

  test(
      'Stale full-object save cannot delete newer weights/photos/health/status',
      () async {
    final stale = await add('Twin');
    await store.recordWeight(stale.id, weightKg: 300, source: 'manual');
    final before = disk;
    await expectLater(
        store.saveCattle(stale.copyWith(notes: 'stale')), throwsStateError);
    expect(disk, before);
    final beforePhoto = store.byId(stale.id)!;
    await store.addPhotos(stale.id, [photo('new.png')]);
    await expectLater(store.saveCattle(beforePhoto), throwsStateError);
    final beforeHealth = store.byId(stale.id)!;
    await store.recordHealth(stale.id,
        kind: HealthKind.observation, occurredAt: now, note: 'Diamati');
    await expectLater(store.saveCattle(beforeHealth), throwsStateError);
    final beforeArchive = store.byId(stale.id)!;
    await store.remove(stale.id);
    await expectLater(store.saveCattle(beforeArchive), throwsStateError);
    expect(store.byId(stale.id)!.images, hasLength(1));
    expect(store.byId(stale.id)!.core.health, hasLength(1));
    expect(store.byId(stale.id)!.status, CattleStatus.archived);
  });

  test(
      'Individual plan IDs are immutable, identical retries perform no write even after reload',
      () async {
    final c = await add('Twin');
    final weighed =
        await store.recordWeight(c.id, weightKg: 300, source: 'manual');
    final p = plan(weighed);
    await store.savePlan(p);
    final before = disk, count = writes;
    store.dispose();
    store = openStore();
    await store.load();
    failWrites = true;
    await store.savePlan(FeedPlan.fromJson(p.toJson()));
    expect(writes, count);
    final conflict = FeedPlan.fromJson({
      ...p.toJson(),
      'notes': ['different payload']
    });
    await expectLater(store.savePlan(conflict), throwsStateError);
    expect(disk, before);
    expect(store.feedPlans.single.notes, isEmpty);
  });

  test(
      'Group plan IDs are immutable, identical stale retries remain idempotent',
      () async {
    final g =
        await store.createGroup('Group', headCount: 10, averageWeightKg: 300);
    final p = GroupFeedPlan(
        id: 'group-plan-1',
        groupId: g.id,
        inputRevision: g.inputRevision,
        headCount: 10,
        averageWeightKg: 300,
        target: g.target,
        createdAt: now,
        availableFeeds: ['rumput'],
        portions: [const FeedPortion(key: 'rumput', asFedKg: 20)]);
    await store.saveGroupPlan(p);
    await store.updateGroup(g.id,
        name: g.name,
        headCount: 20,
        averageWeightKg: 300,
        target: g.target,
        notes: 'Changed');
    store.dispose();
    store = openStore();
    await store.load();
    final count = writes, before = disk;
    await store.saveGroupPlan(GroupFeedPlan.fromJson(p.toJson()));
    expect(writes, count);
    await expectLater(
        store.saveGroupPlan(GroupFeedPlan.fromJson({
          ...p.toJson(),
          'headCount': 20,
          'inputRevision': store.groups.single.inputRevision
        })),
        throwsStateError);
    expect(disk, before);
    expect(store.groupFeedPlans.single.headCount, 10);
  });

  test('Failed append/archive/configuration writes keep the snapshot intact',
      () async {
    final c = await add('Twin');
    final before = disk;
    failWrites = true;
    await expectLater(store.recordWeight(c.id, weightKg: 300, source: 'manual'),
        throwsStateError);
    await expectLater(store.remove(c.id), throwsStateError);
    await expectLater(
        store.configureProductionSystems(FarmProductionSystems.dairy),
        throwsStateError);
    expect(disk, before);
    expect(store.byId(c.id)!.history, isEmpty);
    expect(store.byId(c.id)!.isActive, isTrue);
    expect(store.productionSystems, isNull);
  });

  test('Category changes preserve shared history and both module boundaries',
      () async {
    await store.configureProductionSystems(FarmProductionSystems.both);
    final c = await store.saveCattle(Cattle(
        nameOrId: 'Twin',
        gender: 'Betina',
        ageMonths: 24,
        productionCategory: ProductionCategory.beef,
        modules:
            const TwinModules(beef: BeefExtension(), dairy: DairyExtension())));
    await store.recordWeight(c.id, weightKg: 300, source: 'manual');
    await store.setProductionCategory(c.id, ProductionCategory.dairy,
        reason: 'Koreksi oleh peternak');
    final decoded = FarmBackupCodec.decode(disk!).cattle.single;
    expect(decoded.productionCategory, ProductionCategory.dairy);
    expect(decoded.modules.beef, isNotNull);
    expect(decoded.modules.dairy, isNotNull);
    expect(decoded.history.single.weightKg, 300);
    expect(decoded.core.timeline.last.kind,
        TwinEventKind.productionCategoryChanged);
    await expectLater(
        store.configureProductionSystems(FarmProductionSystems.beef),
        throwsFormatException);
    expect(store.productionSystems, FarmProductionSystems.both);
  });

  test(
      'Reference cycles are rejected atomically; archived parents remain valid',
      () async {
    final a = await add('A'), b = await add('B');
    await store.updateReferences(a.id, TwinReferences(damId: b.id));
    final before = disk;
    await expectLater(store.updateReferences(b.id, TwinReferences(damId: a.id)),
        throwsFormatException);
    expect(disk, before);
    await store.remove(b.id);
    expect(
        FarmBackupCodec.decode(disk!).cattle.first.core.references.damId, b.id);
  });

  test('Invalid status-history ordering and category history are rejected',
      () async {
    await store.configureProductionSystems(FarmProductionSystems.both);
    final c = await add('Twin', category: ProductionCategory.beef);
    await store.setProductionCategory(c.id, ProductionCategory.dairy,
        reason: 'Koreksi');
    final invalidCategory = backup();
    twin(invalidCategory)['productionCategory'] = 'beef';
    expect(() => FarmBackupCodec.decode(jsonEncode(invalidCategory)),
        throwsFormatException);
    await store.remove(c.id);
    await store.setCattleStatus(c.id, CattleStatus.active);
    final invalidStatus = backup();
    ((twin(invalidStatus)['statuses'] as List).first as Map)['recordedAt'] =
        now.add(const Duration(days: 1)).toIso8601String();
    expect(() => FarmBackupCodec.decode(jsonEncode(invalidStatus)),
        throwsFormatException);
  });

  final badData = <String, void Function(Map<String, dynamic>)>{
    'unknown foundation version': (j) =>
        (backupPayload(j)['foundation'] as Map)['version'] = 999,
    'invalid farm type': (j) =>
        (backupPayload(j)['foundation'] as Map)['productionSystems'] = true,
    'unknown farm enum': (j) =>
        (backupPayload(j)['foundation'] as Map)['productionSystems'] = 'mixed',
    'unknown cattle enum': (j) => twin(j)['productionCategory'] = 'mixed',
    'invalid history type': (j) => twin(j)['health'] = {},
    'unknown status': (j) =>
        ((twin(j)['statuses'] as List).first as Map)['status'] = 'deleted',
    'invalid status timestamp': (j) =>
        ((twin(j)['statuses'] as List).first as Map)['recordedAt'] = false,
    'dangling reference': (j) =>
        (twin(j)['references'] as Map)['damId'] = 'missing',
    'self reference': (j) => (twin(j)['references'] as Map)['damId'] =
        (backupPayload(j)['cattle'] as List).first['id'],
    'dangling event': (j) =>
        ((twin(j)['timeline'] as List).first as Map)['recordId'] = 'missing',
    'invalid photo reference': (j) =>
        ((twin(j)['photos'] as List).first as Map)['imageIndex'] = 50,
    'duplicate history id': (j) =>
        (twin(j)['statuses'] as List).add((twin(j)['statuses'] as List).first),
    'unknown module payload': (j) =>
        (twin(j)['modules'] as Map)['beef'] = {'version': 1, 'futureData': []},
    'unknown field': (j) => twin(j)['futureData'] = [],
    'missing envelope': (j) => backupPayload(j).remove('foundation'),
    'null cattle foundation': (j) =>
        (backupPayload(j)['cattle'] as List).first['foundation'] = null,
    'invalid record id': (j) =>
        ((twin(j)['statuses'] as List).first as Map)['id'] = '',
    'unknown twin version': (j) => twin(j)['version'] = 3,
    'out of order timeline': (j) =>
        ((twin(j)['timeline'] as List).first as Map)['recordedAt'] =
            now.add(const Duration(days: 1)).toIso8601String(),
    'wrong event type': (j) =>
        ((twin(j)['timeline'] as List).first as Map)['kind'] = 'healthRecorded',
    'dangling photo weight': (j) => ((twin(j)['photos'] as List).first
        as Map)['weightRecordId'] = 'missing',
    'invalid photo source': (j) =>
        ((twin(j)['photos'] as List).first as Map)['source'] = 'unknown',
    'future health occurrence': (j) => (twin(j)['health'] as List).add({
          'id': 'health-extra',
          'recordedAt': now.toIso8601String(),
          'occurredAt': now.add(const Duration(days: 1)).toIso8601String(),
          'kind': 'observation',
          'note': 'Invalid'
        }),
  };
  for (final bad in badData.entries) {
    test('Rejects ${bad.key} without overwriting current data', () async {
      await store.configureProductionSystems(FarmProductionSystems.beef);
      final c = await add('Twin');
      await store.recordWeight(c.id,
          weightKg: 300, source: 'ai', images: [photo('cow.png')]);
      await store.remove(c.id);
      final data = backup(), before = disk;
      bad.value(data);
      await expectLater(
          store.restoreBackup(jsonEncode(data)), throwsFormatException);
      expect(disk, before);
      expect(store.byId(c.id)!.status, CattleStatus.archived);
    });
  }

  testWidgets(
      'Archived Twin is discoverable and restorable with history retained',
      (tester) async {
    store.dispose();
    store = openStore();
    await store.load();
    final c = await add('Arsip Budi');
    await store.recordWeight(c.id, weightKg: 300, source: 'manual');
    await store.remove(c.id);
    await tester
        .pumpWidget(buildTestApp(store: store, home: const CattleListScreen()));
    await tester.tap(find.text('Arsip'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Arsip Budi'));
    await tester.tap(find.text('Arsip Budi'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Catat bobot manual'));
    final weightButton = tester.widget<OutlinedButton>(find
        .ancestor(
            of: find.text('Catat bobot manual'),
            matching: find.byWidgetPredicate((w) => w is OutlinedButton))
        .first);
    expect(weightButton.onPressed, isNull);
    await reveal(tester, find.byKey(const ValueKey('cattle-feed-button')));
    final feedButton = tester
        .widget<FilledButton>(find.byKey(const ValueKey('cattle-feed-button')));
    expect(feedButton.onPressed, isNull);
    await reveal(tester, find.text('Pulihkan dari arsip'));
    await tester.tap(find.text('Pulihkan dari arsip'));
    await tester.pumpAndSettle();
    expect(store.byId(c.id)!.isActive, isTrue);
    expect(store.byId(c.id)!.history.single.weightKg, 300);
  });
}
