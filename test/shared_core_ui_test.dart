import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_plan.dart';
import 'package:sapita_app/screens/cattle/add_cattle_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_health_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_list_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_profile_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_record_editor_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_timeline_screen.dart';
import 'package:sapita_app/screens/feed/feed_calculator_screen.dart';
import 'package:sapita_app/screens/feed/feed_hub_screen.dart';
import 'package:sapita_app/screens/profile/farm_settings_screen.dart';
import 'package:sapita_app/state/farm_store.dart';
import 'package:sapita_app/widgets/livestock_labels.dart';

import 'helpers/test_app.dart';

class Environment {
  Environment() {
    store = FarmStore(
        read: () async => disk,
        write: (raw) async {
          if (fail) throw StateError('Simpan gagal');
          disk = raw;
        },
        now: () => now);
  }
  String? disk;
  bool fail = false;
  DateTime now = DateTime.utc(2026, 10, 25, 10);
  late final FarmStore store;
  Future<Cattle> add(
          {ProductionCategory? category,
          AgeEvidence evidence = const AgeEvidence(),
          String name = 'Budi'}) =>
      store.saveCattle(Cattle(
          nameOrId: name,
          gender: 'Jantan',
          ageMonths: 18,
          productionCategory: category,
          ageEvidence: evidence));
}

Future<Environment> environment() async {
  final e = Environment();
  await e.store.load();
  addTearDown(e.store.dispose);
  return e;
}

Future<void> reveal(WidgetTester tester, Finder target,
    {double delta = 220}) async {
  await tester.scrollUntilVisible(target, delta,
      scrollable: find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .last,
      maxScrolls: 50);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, Environment e, Widget page) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  await tester.pumpWidget(buildTestApp(
      store: e.store,
      home: Builder(
          builder: (context) => Scaffold(
              body: Center(
                  child: TextButton(
                      onPressed: () => Navigator.push<void>(
                          context, MaterialPageRoute(builder: (_) => page)),
                      child: const Text('Buka')))))));
  await tester.tap(find.text('Buka'));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String key, String text) async {
  final target = find.byKey(ValueKey(key));
  await reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  await reveal(tester, find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings routes farm-type changes through explicit reset flow',
      (tester) async {
    final e = await environment();
    await e.store.configureProductionSystems(FarmProductionSystems.beef);
    final c = await e.add(category: ProductionCategory.beef);
    await open(tester, e, const FarmSettingsScreen());
    expect(find.byKey(const ValueKey('farm-production')), findsNothing);
    await press(tester, 'Ganti jenis peternakan');
    await press(tester, 'Sapi Perah');
    expect(find.textContaining('1 sapi (termasuk arsip)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('farm-type-cancel')));
    await tester.pumpAndSettle();
    expect(e.store.byId(c.id), isNotNull);
    expect(e.store.productionSystems, FarmProductionSystems.beef);
  });
  testWidgets(
      'Concurrent settings and failed write cannot overwrite preferences',
      (tester) async {
    final e = await environment();
    await open(tester, e, const FarmSettingsScreen());
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama pemilik'), 'Draft');
    await e.store.settings('Other', 'Updated', 14);
    final before = e.disk;
    await press(tester, 'Simpan preferensi');
    expect(e.disk, before);
    expect(find.textContaining('Preferensi farm berubah'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester, e, const FarmSettingsScreen());
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama pemilik'), 'Draft again');
    e.fail = true;
    await press(tester, 'Simpan preferensi');
    expect(e.disk, before);
    expect(e.store.productionSystems, isNull);
    expect(find.text('Simpan gagal'), findsOneWidget);
  });
  for (final system in FarmProductionSystems.values) {
    testWidgets('Add cattle follows ${system.name}, Both requires a choice',
        (tester) async {
      final e = await environment();
      await e.store.configureProductionSystems(system);
      await open(tester, e, const AddCattleScreen());
      await tester.enterText(find.byKey(const ValueKey('cattle-name')), 'Sari');
      await reveal(tester, find.byKey(const ValueKey('cattle-age')));
      await tester.enterText(find.byKey(const ValueKey('cattle-age')), '18');
      if (system == FarmProductionSystems.both) {
        await press(tester, 'Simpan sapi');
        expect(e.store.cattle, isEmpty);
        await reveal(
            tester,
            find.widgetWithText(DropdownButtonFormField<ProductionCategory>,
                'Kategori produksi'),
            delta: -220);
        await tester
            .tap(find.byType(DropdownButtonFormField<ProductionCategory>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dairy').last);
        await tester.pumpAndSettle();
      } else {
        expect(find.byType(DropdownButtonFormField<ProductionCategory>),
            findsNothing);
      }
      await press(tester, 'Simpan sapi');
      expect(
          e.store.cattle.single.productionCategory,
          system == FarmProductionSystems.both
              ? ProductionCategory.dairy
              : system.singleCategory);
      expect(find.byType(CattleProfileScreen), findsOneWidget);
    });
  }
  testWidgets(
      'Farm change while adding cattle does not silently reclassify the new profile',
      (tester) async {
    final e = await environment();
    await e.store.configureProductionSystems(FarmProductionSystems.beef);
    await open(tester, e, const AddCattleScreen());
    await tester.enterText(find.byKey(const ValueKey('cattle-name')), 'Sari');
    await reveal(tester, find.byKey(const ValueKey('cattle-age')));
    await tester.enterText(find.byKey(const ValueKey('cattle-age')), '18');
    await e.store.configureProductionSystems(FarmProductionSystems.dairy);
    await press(tester, 'Simpan sapi');
    expect(e.store.cattle, isEmpty);
    expect(find.textContaining('Pengaturan farm berubah'), findsOneWidget);
  });
  testWidgets(
      'Legacy classification and category change require a reason and retain shared/domain history',
      (tester) async {
    final e = await environment();
    final c = await e.store.saveCattle(Cattle(
        nameOrId: 'Budi',
        gender: 'Jantan',
        ageMonths: 18,
        modules:
            const TwinModules(beef: BeefExtension(), dairy: DairyExtension())));
    await e.store.configureProductionSystems(FarmProductionSystems.both);
    await e.store.recordWeight(c.id, weightKg: 300, source: 'manual');
    await open(
        tester,
        e,
        CattleRecordEditorScreen(
            cattle: e.store.byId(c.id)!, kind: CattleRecordEdit.category));
    await choose(tester, 'cattle-category', 'Beef');
    await press(tester, 'Simpan perubahan');
    expect(find.text('Alasan wajib diisi.'), findsOneWidget);
    expect(e.store.byId(c.id)!.productionCategory, isNull);
    await reveal(tester, find.byKey(const ValueKey('record-note')));
    await tester.enterText(
        find.byKey(const ValueKey('record-note')), 'Klasifikasi oleh pemilik');
    await press(tester, 'Simpan perubahan');
    expect(e.store.byId(c.id)!.productionCategory, ProductionCategory.beef);
    await open(
        tester,
        e,
        CattleRecordEditorScreen(
            cattle: e.store.byId(c.id)!, kind: CattleRecordEdit.category));
    await choose(tester, 'cattle-category', 'Dairy');
    await tester.enterText(
        find.byKey(const ValueKey('record-note')), 'Koreksi kategori');
    await press(tester, 'Simpan perubahan');
    final saved = e.store.byId(c.id)!;
    expect(saved.modules.beef, isNotNull);
    expect(saved.modules.dairy, isNotNull);
    expect(saved.history.single.weightKg, 300);
    expect(
        saved.core.timeline
            .where((e) => e.kind == TwinEventKind.productionCategoryChanged),
        hasLength(2));
  });
  testWidgets(
      'Category editor tolerates a changed farm without a dropdown crash and rejects stale save',
      (tester) async {
    final e = await environment();
    await e.store.configureProductionSystems(FarmProductionSystems.both);
    final c = await e.add(category: ProductionCategory.beef);
    await open(tester, e,
        CattleRecordEditorScreen(cattle: c, kind: CattleRecordEdit.category));
    await choose(tester, 'cattle-category', 'Dairy');
    await e.store.configureProductionSystems(FarmProductionSystems.beef);
    await reveal(tester, find.byKey(const ValueKey('record-note')));
    await tester.enterText(find.byKey(const ValueKey('record-note')), 'Reason');
    await press(tester, 'Simpan perubahan');
    expect(tester.takeException(), isNull);
    expect(e.store.byId(c.id)!.productionCategory, ProductionCategory.beef);
    expect(find.textContaining('Pengaturan farm berubah'), findsOneWidget);
  });
  for (final status
      in CattleStatus.values.where((s) => s != CattleStatus.active)) {
    testWidgets('Exit ${status.name} retains Twin/plans, correction reopens it',
        (tester) async {
      final e = await environment();
      final c = await e.add();
      final weighed =
          await e.store.recordWeight(c.id, weightKg: 300, source: 'manual');
      await e.store.savePlan(FeedPlan(
          id: 'p',
          cattleId: c.id,
          cattleName: c.nameOrId,
          weightKg: 300,
          ageMonths: 18,
          gender: 'Jantan',
          bodyCondition: 'Sedang',
          target: 'pemeliharaan',
          availableFeeds: ['rumput'],
          createdAt: e.now,
          weightDate: weighed.history.last.date,
          portions: [const FeedPortion(key: 'rumput', asFedKg: 20)]));
      await open(
          tester,
          e,
          CattleRecordEditorScreen(
              cattle: e.store.byId(c.id)!, kind: CattleRecordEdit.status));
      await choose(tester, 'cattle-status', status.label);
      await press(tester, 'Simpan perubahan');
      expect(e.store.cattle, isEmpty);
      expect(e.store.byId(c.id)!.status, status);
      expect(e.store.feedPlans, hasLength(1));
      expect(e.store.commandCenter.cattleCount, 0);
      expect(e.store.byId(c.id)!.history, hasLength(1));
      await open(
          tester,
          e,
          CattleRecordEditorScreen(
              cattle: e.store.byId(c.id)!, kind: CattleRecordEdit.status));
      await choose(tester, 'cattle-status', 'Aktif');
      await press(tester, 'Simpan perubahan');
      expect(e.store.cattle, hasLength(1));
      expect(e.store.byId(c.id)!.core.lifecycle.statuses.map((r) => r.status),
          [status, CattleStatus.active]);
    });
  }
  testWidgets(
      'Status save failure and stale status do not erase concurrent health/status',
      (tester) async {
    final e = await environment();
    final c = await e.add();
    await open(tester, e,
        CattleRecordEditorScreen(cattle: c, kind: CattleRecordEdit.status));
    await choose(tester, 'cattle-status', 'Terjual');
    e.fail = true;
    await press(tester, 'Simpan perubahan');
    expect(e.store.byId(c.id)!.status, CattleStatus.active);
    e.fail = false;
    await e.store.recordHealth(c.id,
        kind: HealthKind.observation, occurredAt: e.now, note: 'Concurrent');
    await press(tester, 'Simpan perubahan');
    expect(e.store.byId(c.id)!.status, CattleStatus.active);
    expect(e.store.byId(c.id)!.core.health, hasLength(1));
    expect(find.textContaining('Data ternak berubah'), findsOneWidget);
  });
  testWidgets('Shared life stage is an explicit append-only observation',
      (tester) async {
    final e = await environment();
    final c = await e.add();
    await open(tester, e,
        CattleRecordEditorScreen(cattle: c, kind: CattleRecordEdit.lifeStage));
    await choose(tester, 'cattle-life-stage', 'Ternak muda');
    await press(tester, 'Simpan perubahan');
    expect(e.store.byId(c.id)!.core.lifecycle.stage, LifeStage.youngstock);
    expect(e.store.byId(c.id)!.core.lifecycle.stages, hasLength(1));
  });
  for (final kind in HealthKind.values) {
    testWidgets(
        'Health ${kind.name} add/read preserves occurred time and optional schedule',
        (tester) async {
      final e = await environment();
      final c = await e.add();
      await open(tester, e, CattleHealthEditorScreen(cattleId: c.id));
      await choose(tester, 'health-kind', healthKindLabel(kind));
      await reveal(tester, find.byKey(const ValueKey('health-note')));
      await tester.enterText(
          find.byKey(const ValueKey('health-note')), 'Catatan pemilik');
      await reveal(tester, find.byKey(const ValueKey('health-due')));
      await tester.enterText(find.byKey(const ValueKey('health-due')),
          inputTime(e.now.toLocal().add(const Duration(days: 7))));
      await press(tester, 'Simpan catatan kesehatan');
      expect(e.store.byId(c.id)!.core.health.single.kind, kind);
      await open(tester, e, CattleHealthScreen(cattleId: c.id));
      expect(find.text('Catatan pemilik'), findsOneWidget);
      expect(find.textContaining('Jadwal berikutnya:'), findsOneWidget);
    });
  }
  testWidgets(
      'Health invalid input, write failure and inactive guard keep user notes and history safe',
      (tester) async {
    final e = await environment();
    final c = await e.add();
    await open(tester, e, CattleHealthEditorScreen(cattleId: c.id));
    await press(tester, 'Simpan catatan kesehatan');
    expect(e.store.byId(c.id)!.core.health, isEmpty);
    await reveal(tester, find.byKey(const ValueKey('health-note')),
        delta: -220);
    await tester.enterText(
        find.byKey(const ValueKey('health-note')), 'Observed');
    await reveal(tester, find.byKey(const ValueKey('health-occurred')),
        delta: -220);
    await tester.enterText(
        find.byKey(const ValueKey('health-occurred')), '2026-02-31 10:00');
    await press(tester, 'Simpan catatan kesehatan');
    expect(e.store.byId(c.id)!.core.health, isEmpty);
    await reveal(tester, find.byKey(const ValueKey('health-occurred')),
        delta: -220);
    await tester.enterText(find.byKey(const ValueKey('health-occurred')),
        inputTime(e.now.toLocal()));
    e.fail = true;
    await press(tester, 'Simpan catatan kesehatan');
    expect(e.store.byId(c.id)!.core.health, isEmpty);
    expect(find.text('Simpan gagal'), findsOneWidget);
    e.fail = false;
    await e.store.setCattleStatus(c.id, CattleStatus.sold);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find
                .ancestor(
                    of: find.text('Simpan catatan kesehatan'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton))
                .first)
            .onPressed,
        isNull);
    expect(e.store.byId(c.id)!.core.health, isEmpty);
  });
  testWidgets(
      'Timeline uses persistent records in newest-first order and survives reload',
      (tester) async {
    final e = await environment();
    final c = await e.add();
    await e.store.recordWeight(c.id, weightKg: 300, source: 'manual');
    e.now = e.now.add(const Duration(hours: 1));
    await e.store.recordHealth(c.id,
        kind: HealthKind.observation,
        occurredAt: e.now,
        note: 'First observation');
    e.now = e.now.add(const Duration(hours: 1));
    await e.store
        .setCattleStatus(c.id, CattleStatus.sold, note: 'Sold by owner');
    await e.store.load();
    final events = e.store.byId(c.id)!.core.timeline.reversed.toList();
    await open(tester, e, CattleTimelineScreen(cattleId: c.id));
    expect(find.text('Status: Terjual'), findsOneWidget);
    await reveal(tester, find.byKey(ValueKey('timeline-${events.last.id}')));
    expect(
        tester
            .getTopLeft(find.byKey(ValueKey('timeline-${events.first.id}')))
            .dy,
        lessThan(tester
            .getTopLeft(find.byKey(ValueKey('timeline-${events.last.id}')))
            .dy));
    expect(e.store.byId(c.id)!.core.timeline, hasLength(3));
  });
  for (final certainty in AgeCertainty.values) {
    testWidgets(
        'Profile renders ${certainty.name} honestly and edit retains its evidence',
        (tester) async {
      final e = await environment();
      final evidence = AgeEvidence(
          certainty: certainty,
          birthDate: certainty == AgeCertainty.exact ? '2018-07-15' : null);
      final c = await e.add(evidence: evidence);
      await open(tester, e, CattleProfileScreen(cattle: c));
      expect(find.textContaining(ageEvidenceLabel(c)), findsWidgets);
      await open(tester, e, AddCattleScreen(cattle: c));
      if (certainty == AgeCertainty.estimated) {
        expect(find.byKey(const ValueKey('cattle-age')), findsOneWidget);
      } else {
        expect(find.byKey(const ValueKey('cattle-age')), findsNothing);
      }
      await tester.enterText(
          find.byKey(const ValueKey('cattle-name')), 'Renamed');
      await press(tester, 'Simpan sapi');
      expect(
          e.store.byId(c.id)!.core.identity.ageEvidence.certainty, certainty);
      expect(e.store.byId(c.id)!.core.identity.ageEvidence.birthDate,
          evidence.birthDate);
      if (certainty == AgeCertainty.unknown) {
        await e.store.configureProductionSystems(FarmProductionSystems.beef);
        await e.store.setProductionCategory(c.id, ProductionCategory.beef,
            reason: 'Explicit feed context for age rendering');
        await e.store.recordWeight(c.id, weightKg: 300, source: 'manual');
        await open(tester, e, const FeedHubScreen());
        expect(find.textContaining('Umur belum diketahui'), findsWidgets);
        await open(tester, e, FeedCalculatorScreen(cattleId: c.id));
        expect(find.textContaining('Umur belum diketahui'), findsWidgets);
      }
    });
  }

  testWidgets(
      'Estimated DOB is displayed as an estimate and is not overwritten by basic editing',
      (tester) async {
    final e = await environment();
    final c = await e.add(
        evidence: const AgeEvidence(
            certainty: AgeCertainty.estimated, birthDate: '2018-07-15'));
    await open(tester, e, CattleProfileScreen(cattle: c));
    expect(find.textContaining('Perkiraan tanggal lahir: 2018-07-15'),
        findsWidgets);
    await open(tester, e, AddCattleScreen(cattle: c));
    expect(find.byKey(const ValueKey('cattle-age')), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('cattle-name')), 'Renamed');
    await press(tester, 'Simpan sapi');
    expect(
        e.store.byId(c.id)!.core.identity.ageEvidence.birthDate, '2018-07-15');
    expect(e.store.byId(c.id)!.core.identity.ageEvidence.certainty,
        AgeCertainty.estimated);
  });
  testWidgets(
      'Both category filters show actual active Beef/Dairy and unclassified profiles',
      (tester) async {
    final e = await environment();
    await e.add(name: 'Legacy');
    await e.store.configureProductionSystems(FarmProductionSystems.both);
    await e.add(category: ProductionCategory.beef, name: 'Beef Cow');
    await e.add(category: ProductionCategory.dairy, name: 'Dairy Cow');
    await open(tester, e, const CattleListScreen());
    await tester.tap(find.text('Dairy'));
    await tester.pumpAndSettle();
    expect(find.text('Dairy Cow'), findsOneWidget);
    expect(find.text('Beef Cow'), findsNothing);
    await tester.tap(find.text('Beef'));
    await tester.pumpAndSettle();
    expect(find.text('Beef Cow'), findsOneWidget);
    expect(find.text('Dairy Cow'), findsNothing);
    await tester.tap(find.text('Belum diklasifikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Legacy'), findsOneWidget);
  });
  testWidgets(
      'Inactive filter exposes history while profile edits and health adds stay disabled',
      (tester) async {
    final e = await environment();
    final c = await e.add();
    await e.store.setCattleStatus(c.id, CattleStatus.deceased);
    await open(tester, e, const CattleListScreen());
    await tester.tap(find.text('Nonaktif'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Budi'));
    await tester.tap(find.text('Budi'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Edit profil sapi'))
            .onPressed,
        isNull);
    await reveal(tester, find.text('Catat bobot manual'));
    expect(
        tester
            .widget<OutlinedButton>(find
                .ancestor(
                    of: find.text('Catat bobot manual'),
                    matching:
                        find.byWidgetPredicate((w) => w is OutlinedButton))
                .first)
            .onPressed,
        isNull);
    await open(tester, e, CattleHealthScreen(cattleId: c.id));
    expect(
        tester
            .widget<FilledButton>(find
                .ancestor(
                    of: find.text('Tambah catatan kesehatan'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton))
                .first)
            .onPressed,
        isNull);
  });
  testWidgets('New shared forms preserve dirty input on back navigation',
      (tester) async {
    final e = await environment();
    final c = await e.add();
    await open(tester, e,
        CattleRecordEditorScreen(cattle: c, kind: CattleRecordEdit.category));
    await reveal(tester, find.byKey(const ValueKey('record-note')));
    await tester.enterText(
        find.byKey(const ValueKey('record-note')), 'Keep this');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Perubahan belum disimpan'), findsOneWidget);
    await tester.tap(find.text('Lanjut mengisi'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this'), findsOneWidget);
    expect(e.store.byId(c.id)!.productionCategory, isNull);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('Shared profile and health form fit width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final e = await environment();
      final c = await e.add();
      final parent = await e.add(name: 'Induk Data');
      await e.store.setCattleStatus(parent.id, CattleStatus.sold);
      await e.store.updateReferences(c.id,
          TwinReferences(damId: parent.id, externalIds: {'Tag': 'ID-123'}));
      await open(tester, e, CattleProfileScreen(cattle: c));
      await reveal(tester, find.text('Tag: ID-123'));
      await reveal(tester, find.text('Lihat aktivitas'));
      expect(tester.takeException(), isNull);
      await open(tester, e, CattleHealthEditorScreen(cattleId: c.id));
      await reveal(tester, find.text('Simpan catatan kesehatan'));
      expect(tester.takeException(), isNull);
    });
  }
}
