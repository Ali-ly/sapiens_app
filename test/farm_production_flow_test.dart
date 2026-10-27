import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapita_app/app.dart';
import 'package:sapita_app/data/farm_backup_codec.dart';
import 'package:sapita_app/models/beef/beef_feed_context.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_stock.dart';
import 'package:sapita_app/models/selected_image.dart';
import 'package:sapita_app/screens/cattle/cattle_profile_screen.dart';
import 'package:sapita_app/screens/profile/farm_production_screen.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/legacy_feed_plan_fixture.dart';
import 'helpers/test_app.dart';

void main() {
  String? disk;
  bool fail = false;
  late FarmStore store;
  Future<void> setup() async {
    disk = null;
    fail = false;
    store = FarmStore(
        read: () async => disk,
        write: (raw) async {
          if (fail) throw StateError('Disk unavailable');
          disk = raw;
        });
    await store.load();
    addTearDown(store.dispose);
  }

  Future<void> select(ProductionCategory category, {bool clear = false}) =>
      store.selectFarmProduction(category,
          expectedRevision: store.productionChangeRevision,
          confirmPermanentDeletion: clear);

  for (final category in ProductionCategory.values) {
    testWidgets(
        'Startup chooses ${category.name} before adding cattle and remembers it',
        (t) async {
      await setup();
      await t.pumpWidget(SapiensApp(store: store));
      await t.pumpAndSettle();
      expect(find.text('Tambah sapi pertama'), findsNothing);
      await t.tap(find.byKey(ValueKey('farm-type-${category.name}')));
      await t.pumpAndSettle();
      expect(find.text('Kamu beternak sapi apa?'), findsNothing);
      expect(find.text('Tambah sapi pertama'), findsOneWidget);
      final c = await store.saveCattle(
          Cattle(nameOrId: 'New Twin', gender: 'Betina', ageMonths: 24));
      expect(c.productionCategory, category);
      final reloaded = FarmStore(read: () async => disk, write: (_) async {});
      await reloaded.load();
      expect(reloaded.productionSystems?.singleCategory, category);
      expect(reloaded.byId(c.id)?.productionCategory, category);
      reloaded.dispose();
      expect(t.takeException(), isNull);
    });

    testWidgets('Profile exposes only ${category.name} data first', (t) async {
      await setup();
      await select(category);
      final c = await store.saveCattle(
          Cattle(nameOrId: 'Twin', gender: 'Betina', ageMonths: 24));
      await t.pumpWidget(
          buildTestApp(store: store, home: CattleProfileScreen(cattle: c)));
      await t.pumpAndSettle();
      final target = find.text(category == ProductionCategory.beef
          ? 'Data ternak pedaging'
          : 'Data ternak perah');
      await t.scrollUntilVisible(target, 200,
          scrollable: find.byType(Scrollable).first);
      expect(target, findsOneWidget);
      expect(
          find.text(category == ProductionCategory.beef
              ? 'Data ternak perah'
              : 'Data ternak pedaging'),
          findsNothing);
      expect(find.text('Ubah kategori'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }

  test(
      'Explicit reset permanently removes active/inactive cattle and individual data, keeps farm/groups/stock, round trips',
      () async {
    await setup();
    await select(ProductionCategory.beef);
    await store.settings('Ali', 'Farm', 14);
    final farmId = store.farmId;
    final cow = await store.saveCattle(
        Cattle(nameOrId: 'Old Twin', gender: 'Betina', ageMonths: 24));
    await store.recordWeight(cow.id, weightKg: 300, source: 'manual');
    await store.recordHealth(cow.id,
        kind: HealthKind.observation,
        occurredAt: DateTime.now(),
        note: 'Original health');
    await store.recordBeef(cow.id,
        kind: BeefRecordKind.purpose,
        purpose: BeefPurpose.fattening,
        note: 'Original purpose');
    await store.recordBeef(cow.id,
        kind: BeefRecordKind.phase,
        phase: BeefPhase.finishing,
        note: 'Recorded phase');
    final bytes = Uint8List.fromList([1, 2, 3]);
    await store.addPhotos(cow.id, [
      SelectedImage(file: XFile.fromData(bytes, name: 'cow.jpg'), bytes: bytes)
    ]);
    await store.savePlan(legacyFeedPlan(
        cattle: store.byId(cow.id)!,
        beefContext: BeefFeedContext(
            revision: store.byId(cow.id)!.modules.beef!.records.length,
            purpose: BeefPurpose.fattening,
            phase: BeefPhase.finishing),
        createdAt: store.currentTime));
    await store.remove(cow.id);
    final group = await store.createGroup('Independent group',
        headCount: 10, averageWeightKg: 300);
    await store.recordStock(
        feed: 'rumput',
        kind: StockMovement.received,
        kg: 100,
        note: 'Existing stock');
    final before = disk;
    await expectLater(select(ProductionCategory.dairy), throwsStateError);
    expect(disk, before);
    await select(ProductionCategory.dairy, clear: true);
    expect(store.allCattle, isEmpty);
    expect(store.feedPlans, isEmpty);
    expect(store.byId(cow.id), isNull);
    final snapshot = FarmBackupCodec.decode(disk!);
    expect(snapshot.cattle, isEmpty);
    expect(snapshot.legacyMemberships, isEmpty);
    expect(snapshot.feedPlans, isEmpty);
    expect(snapshot.groups.single.id, group.id);
    expect(snapshot.feedStock.single.kg, 100);
    expect(store.farmId, farmId);
    expect(store.farmer, 'Ali');
    final next = await store.saveCattle(
        Cattle(nameOrId: 'New Dairy', gender: 'Betina', ageMonths: 24));
    expect(next.productionCategory, ProductionCategory.dairy);
    expect(next.id, isNot(cow.id));
  });

  test('Failed disk write and changed revision cannot reset data', () async {
    await setup();
    await select(ProductionCategory.beef);
    final cow = await store
        .saveCattle(Cattle(nameOrId: 'Kept', gender: 'Betina', ageMonths: 24));
    var before = disk;
    fail = true;
    await expectLater(
        select(ProductionCategory.dairy, clear: true), throwsStateError);
    expect(disk, before);
    expect(store.byId(cow.id), isNotNull);
    expect(store.productionSystems, FarmProductionSystems.beef);
    fail = false;
    final revision = store.productionChangeRevision;
    await store.recordWeight(cow.id, weightKg: 301, source: 'manual');
    before = disk;
    await expectLater(
        store.selectFarmProduction(ProductionCategory.dairy,
            expectedRevision: revision, confirmPermanentDeletion: true),
        throwsStateError);
    expect(disk, before);
    expect(store.byId(cow.id)!.history, hasLength(1));
  });

  testWidgets(
      'Change confirmation cancels safely then switches and clears history',
      (t) async {
    await setup();
    await select(ProductionCategory.beef);
    final cow = await store.saveCattle(
        Cattle(nameOrId: 'Old Twin', gender: 'Betina', ageMonths: 24));
    await t.pumpWidget(buildTestApp(
        store: store, home: const FarmProductionScreen(changing: true)));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('farm-type-dairy')));
    await t.pumpAndSettle();
    expect(find.textContaining('1 sapi (termasuk arsip)'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('farm-type-cancel')));
    await t.pumpAndSettle();
    expect(store.byId(cow.id), isNotNull);
    await t.tap(find.byKey(const ValueKey('farm-type-dairy')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('farm-type-confirm-delete')));
    await t.pumpAndSettle();
    expect(store.allCattle, isEmpty);
    expect(store.productionSystems, FarmProductionSystems.dairy);
  });

  test('Selecting the current type is a no-op and retains history', () async {
    await setup();
    await select(ProductionCategory.dairy);
    final c = await store.saveCattle(
        Cattle(nameOrId: 'Kept Dairy', gender: 'Betina', ageMonths: 24));
    await store.recordWeight(c.id, weightKg: 300, source: 'manual');
    final before = disk;
    await select(ProductionCategory.dairy);
    expect(disk, before);
    expect(store.byId(c.id)!.history, hasLength(1));
  });

  testWidgets('Deleted profile does not render the old in-memory Twin',
      (t) async {
    await setup();
    await select(ProductionCategory.beef);
    final c = await store.saveCattle(
        Cattle(nameOrId: 'Deleted Twin', gender: 'Betina', ageMonths: 24));
    await t.pumpWidget(
        buildTestApp(store: store, home: CattleProfileScreen(cattle: c)));
    await t.pumpAndSettle();
    await select(ProductionCategory.dairy, clear: true);
    await t.pumpAndSettle();
    expect(find.text('Profil tidak tersedia'), findsOneWidget);
    expect(find.text('Deleted Twin'), findsNothing);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('Initial farm picker fits width $width', (t) async {
      await setup();
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(SapiensApp(store: store));
      await t.pumpAndSettle();
      expect(find.text('Sapi Pedaging'), findsOneWidget);
      expect(find.text('Sapi Perah'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'Legacy Both requires initial selection without automatically changing data',
      (t) async {
    await setup();
    await store.configureProductionSystems(FarmProductionSystems.both);
    final cow = await store.saveCattle(Cattle(
        nameOrId: 'Beef',
        gender: 'Betina',
        ageMonths: 24,
        productionCategory: ProductionCategory.beef));
    final before = disk;
    await t.pumpWidget(SapiensApp(store: store));
    await t.pumpAndSettle();
    expect(find.text('Kamu beternak sapi apa?'), findsOneWidget);
    expect(disk, before);
    await t.tap(find.byKey(const ValueKey('farm-type-dairy')));
    await t.pumpAndSettle();
    expect(store.byId(cow.id), isNotNull);
    await t.tap(find.byKey(const ValueKey('farm-type-cancel')));
    await t.pumpAndSettle();
    expect(disk, before);
  });
}
