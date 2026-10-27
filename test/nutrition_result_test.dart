import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/data/farm_backup_codec.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_api_v2.dart';
import 'package:sapita_app/models/feed_plan.dart';
import 'package:sapita_app/models/feed_plan_rules.dart';
import 'package:sapita_app/screens/feed/feed_hub_screen.dart';
import 'package:sapita_app/screens/feed/feed_result_screen.dart';
import 'package:sapita_app/screens/feed/nutrition_result_screen.dart';
import 'package:sapita_app/services/cattle_nutrition_context.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/beef_environment.dart';
import 'helpers/dairy_environment.dart';
import 'helpers/test_app.dart';

Map<String, dynamic> nutritionData({bool partial = true}) => {
      'production_category': 'dairy',
      'requirement': {
        'protein': {'value': 100, 'unit': 'g/day'}
      },
      'supply': {
        'protein': {'value': 80, 'unit': 'g/day', 'status': 'cukup'}
      },
      'adequacy': {
        'status': partial ? 'not_fully_evaluable' : 'evaluated',
        'protein': {'status': 'cukup'},
        'energy': {'status': 'kurang'}
      },
      'warnings': ['Milk mass missing'],
      'assumptions': ['Manual input'],
      'defaults_used': {'source': 'backend supplied default'},
      'coverage': {
        'known': ['protein'],
        'status': 'partial'
      },
      'confidence': {
        'level': 'low',
        'source': 'profile',
        'protein': {'status': 'cukup'}
      },
      'future_field': {'provenance': 'backend-v2'},
    };

Future<(DairyEnvironment, Cattle)> environment() async {
  final e = DairyEnvironment();
  await e.store.load();
  final c = await e.add('Dairy');
  await e.store.recordWeight(c.id, weightKg: 450, source: 'manual');
  await e.birth(c.id, '2026-10-01', parity: 2);
  await e.store.recordDairy(c.id,
      kind: DairyRecordKind.phase,
      day: '2026-10-26',
      phase: DairyPhase.fresh,
      note: 'Explicit stage');
  return (e, e.store.byId(c.id)!);
}

FeedPlan draft(DairyEnvironment e, Cattle c, {Map<String, dynamic>? data}) =>
    e.store.createNutritionPlan(
        cattle: c,
        request: NutritionRequest(
            cattle: CattleNutritionContext.fromTwin(c, e.now),
            feedItems: [
              NutritionFeedItem(feedId: 'rumput_gajah', asFedKgDay: 25)
            ]),
        response: NutritionResponse.fromJson(data ?? nutritionData()));

Future<void> reveal(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 220,
      scrollable: find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .last,
      maxScrolls: 80);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'Hub presents native evaluation as history rather than stale active ration',
      (t) async {
    final (e, c) = await environment();
    await e.store.configureProductionSystems(FarmProductionSystems.dairy);
    await e.store.savePlan(draft(e, c));
    await t
        .pumpWidget(buildTestApp(store: e.store, home: const FeedHubScreen()));
    await t.pumpAndSettle();
    expect(find.text('1 dari 1 sapi'), findsOneWidget);
    expect(find.text('memiliki evaluasi pakan tersimpan'), findsOneWidget);
    await reveal(t, find.text('Lihat evaluasi'));
    expect(find.text('Evaluasi tersimpan'), findsOneWidget);
    expect(find.text('Input bahan evaluasi / hari'), findsOneWidget);
    expect(
        find.textContaining('Bobot perlu dicek atau data sapi telah berubah'),
        findsNothing);
    expect(e.store.planReady(e.store.byId(c.id)!), isFalse);
    await t.tap(find.text('Lihat evaluasi'));
    await t.pumpAndSettle();
    expect(find.text('Evaluasi tersimpan sebagai snapshot histori.'),
        findsOneWidget);
  });

  test('Explicit evaluation ADG persists without weakening stale Twin guard',
      () async {
    final e = BeefEnvironment();
    await e.store.load();
    final c = await e.add('Live Beef');
    await e.setup(c.id);
    await e.store.recordWeight(c.id, weightKg: 300, source: 'manual');
    final current = e.store.byId(c.id)!;
    final request = NutritionRequest(
        cattle: NutritionCattleContext.beef(
            bodyWeightKg: 300, purpose: 'penggemukan', targetAdgKgDay: 0.5),
        feedItems: [NutritionFeedItem(feedId: 'rumput_gajah', asFedKgDay: 25)]);
    final plan = e.store.createNutritionPlan(
        cattle: current,
        request: request,
        response: NutritionResponse.fromJson({
          'production_category': 'beef',
          'feed_supply': {'total_as_fed_kg_day': 25},
          'status': 'ok'
        }));
    await e.store.savePlan(plan);
    final restored = FarmStore(
        read: () async => e.disk, write: (_) async {}, now: () => e.now);
    await restored.load();
    expect(restored.error, isNull);
    expect(
        restored.feedPlans.single.nutritionRequest!.cattle
            .data['target_adg_kg_day'],
        0.5);
    expect(restored.nutritionPlanMatches(restored.feedPlans.single), isTrue);
    await restored.recordWeight(c.id, weightKg: 310, source: 'manual');
    expect(restored.nutritionPlanMatches(restored.feedPlans.single), isFalse);
    expect(restored.feedPlans.single.toJson(), plan.toJson());
    restored.dispose();
    e.store.dispose();
  });
  testWidgets(
      'Live feed_supply uses nutrient supply label without changing JSON',
      (t) async {
    final response = NutritionResponse.fromJson({
      'production_category': 'beef',
      'feed_supply': {'total_as_fed_kg_day': 25}
    });
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NutritionResultContent(
                response: response, category: ProductionCategory.beef))));
    expect(find.text('Pasokan nutrien'), findsOneWidget);
    expect(response.data['feed_supply'], {'total_as_fed_kg_day': 25});
  });

  testWidgets(
      'Legacy ration history stays readable without the obsolete individual save action',
      (t) async {
    final e = BeefEnvironment();
    await e.store.load();
    final c = await e.add('History');
    await e.setup(c.id);
    final plan = await e.plan(c.id);
    await e.store.savePlan(plan);
    await t.pumpWidget(
        buildTestApp(store: e.store, home: FeedResultScreen(plan: plan)));
    await t.pumpAndSettle();
    expect(find.text('Rencana pakan'), findsOneWidget);
    await reveal(t, find.text('Selesai'));
    expect(find.text('Gunakan & simpan rencana'), findsNothing);
    expect(find.text('Simpan sebagai catatan'), findsNothing);
    expect(e.store.feedPlans.single.toJson(), plan.toJson());
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Partial Dairy displays exact backend data, no nutrient sufficiency labels, actual coverage/confidence',
      (t) async {
    final (e, c) = await environment();
    final plan = draft(e, c);
    await t.pumpWidget(
        buildTestApp(store: e.store, home: FeedResultScreen(plan: plan)));
    await t.pumpAndSettle();
    expect(find.text('Hasil evaluasi nutrisi'), findsOneWidget);
    await reveal(t, find.text('Kebutuhan nutrisi'));
    expect(find.text('100'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('cukup'), findsNothing);
    expect(find.text('kurang'), findsNothing);
    expect(find.text('Belum dapat dievaluasi penuh'), findsWidgets);
    await reveal(t, find.text('Confidence'));
    expect(find.text('low'), findsOneWidget);
    expect(find.text('Coverage'), findsOneWidget);
    expect(plan.nutritionSnapshot!.response.toJson(), nutritionData());
    await reveal(t, find.text('Simpan evaluasi'));
    await t.tap(find.text('Simpan evaluasi'));
    await t.pumpAndSettle();
    expect(e.store.feedPlans.single.type, FeedPlanType.nutritionEvaluation);
    expect(e.store.feedPlans.single.nutritionSnapshot!.response.toJson(),
        nutritionData());
    expect(e.store.planReady(c), isFalse);
    expect(e.store.dailyFeedTotals, isEmpty);
  });

  testWidgets(
      'Missing/null coverage and confidence do not create panels or invented scores',
      (t) async {
    final (e, c) = await environment();
    final plan = draft(e, c, data: {
      'production_category': 'dairy',
      'confidence': null,
      'coverage': null
    });
    await t.pumpWidget(
        buildTestApp(store: e.store, home: FeedResultScreen(plan: plan)));
    await t.pumpAndSettle();
    expect(find.text('Confidence'), findsNothing);
    expect(find.text('Coverage'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.text('cukup'), findsNothing);
  });

  testWidgets(
      'Beef renders backend adequacy status without applying Dairy suppression',
      (t) async {
    final response = NutritionResponse.fromJson({
      'adequacy': {
        'protein': {'status': 'adequate'}
      },
      'confidence': 0,
    });
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SingleChildScrollView(
          child: NutritionResultContent(
        category: ProductionCategory.beef,
        response: response,
      )),
    )));
    expect(find.text('adequate'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Belum dapat dievaluasi penuh'), findsNothing);
  });

  testWidgets('Save failure retains the response and can retry once',
      (t) async {
    final (e, c) = await environment();
    final plan = draft(e, c);
    e.fail = true;
    await t.pumpWidget(
        buildTestApp(store: e.store, home: FeedResultScreen(plan: plan)));
    await t.pumpAndSettle();
    await reveal(t, find.text('Simpan evaluasi'));
    await t.tap(find.text('Simpan evaluasi'));
    await t.pumpAndSettle();
    expect(e.store.feedPlans, isEmpty);
    expect(plan.nutritionSnapshot!.response.toJson(), nutritionData());
    e.fail = false;
    await reveal(t, find.text('Simpan evaluasi'));
    await t.tap(find.text('Simpan evaluasi'));
    await t.pumpAndSettle();
    expect(e.store.feedPlans, hasLength(1));
  });

  testWidgets(
      'Changed Twin blocks saving; saved inactive history remains readable',
      (t) async {
    final (e, c) = await environment();
    final plan = draft(e, c);
    await e.store.recordWeight(c.id, weightKg: 460, source: 'manual');
    await t.pumpWidget(
        buildTestApp(store: e.store, home: FeedResultScreen(plan: plan)));
    await t.pumpAndSettle();
    await reveal(t, find.text('Simpan evaluasi'));
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Simpan evaluasi'))
            .onPressed,
        isNull);
    final fresh = draft(e, e.store.byId(c.id)!);
    await e.store.savePlan(fresh);
    await e.store.remove(c.id);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(buildTestApp(
        store: e.store, home: FeedResultScreen(plan: fresh, saved: true)));
    await t.pumpAndSettle();
    expect(find.text('Hasil evaluasi nutrisi'), findsOneWidget);
    expect(find.text('Simpan evaluasi'), findsNothing);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('Result generic nested fields fit width $width', (t) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final (e, c) = await environment();
      await t.pumpWidget(buildTestApp(
          store: e.store, home: FeedResultScreen(plan: draft(e, c))));
      await t.pumpAndSettle();
      await reveal(t, find.text('Simpan evaluasi'));
      expect(t.takeException(), isNull);
    });
  }

  test(
      'Native evaluation round trip has explicit kind, immutable request and lossless response',
      () async {
    final (e, c) = await environment();
    final plan = draft(e, c);
    expect(plan.target, isNull);
    expect(plan.bodyCondition, isNull);
    final loaded = FeedPlan.fromJson(
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>);
    expect(loaded.toJson(), plan.toJson());
    expect(
        loaded.nutritionRequest!.productionCategory, ProductionCategory.dairy);
    expect(() => loaded.nutritionRequest!.cattle.data['dim'] = 999,
        throwsUnsupportedError);
    await e.store.savePlan(plan);
    final backup = e.store.exportData();
    final restored = FarmStore(
        read: () async => null, write: (_) async {}, now: () => e.now);
    await restored.load();
    await restored.restoreBackup(jsonEncode(backup));
    expect(restored.feedPlans.single.toJson(), plan.toJson());
    expect(
        FarmBackupCodec.encode(
            FarmBackupCodec.decode(jsonEncode(backup)))['data'],
        backup['data']);
  });

  test(
      'Beef legacy and v2 plans coexist; neither evaluation status nor quantities activate stock',
      () async {
    final e = BeefEnvironment();
    await e.store.load();
    final c = await e.add('Beef');
    await e.setup(c.id);
    final legacy = await e.plan(c.id);
    await e.store.savePlan(legacy);
    e.now = legacy.createdAt.toUtc().add(const Duration(seconds: 1));
    final current = e.store.byId(c.id)!;
    final plan = e.store.createNutritionPlan(
        cattle: current,
        request: NutritionRequest(
            cattle: CattleNutritionContext.fromTwin(current, e.now),
            feedItems: [
              NutritionFeedItem(feedId: 'new_backend_feed', asFedKgDay: 12)
            ]),
        response: NutritionResponse.fromJson({
          'production_category': 'beef',
          'adequacy': {'status': 'adequate'}
        }));
    await e.store.savePlan(plan);
    expect(e.store.feedPlans.first.toJson(), legacy.toJson());
    expect(e.store.feedPlans.last.isNutritionEvaluation, isTrue);
    expect(e.store.planReady(current), isFalse);
    expect(e.store.dailyFeedTotals, isEmpty);
    expect(e.store.beefDemand().eligible, 0);
    final reloaded = FarmBackupCodec.decode(jsonEncode(e.store.exportData()));
    expect(reloaded.feedPlans.map((p) => p.toJson()).toList(),
        [legacy.toJson(), plan.toJson()]);
  });

  test('Changed Dairy stage or DIM cannot save an old draft', () async {
    final (e, c) = await environment();
    final plan = draft(e, c);
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.phase,
        day: '2026-10-26',
        phase: DairyPhase.early,
        note: 'Explicit transition');
    await expectLater(e.store.savePlan(plan), throwsStateError);
    final updated = draft(e, e.store.byId(c.id)!);
    e.now = e.now.add(const Duration(days: 1));
    await expectLater(e.store.savePlan(updated), throwsStateError);
    expect(e.store.feedPlans, isEmpty);
  });

  test('Type/input mismatch or altered input portions are rejected', () async {
    final (e, c) = await environment();
    final plan = draft(e, c);
    final json = plan.toJson();
    for (final broken in [
      {...json, 'nutritionRequest': null},
      {...json, 'planType': 'legacyRation'},
      {...json, 'target': 'penggemukan'},
      {
        ...json,
        'portions': [
          {
            'key': 'rumput_gajah',
            'asFedKg': 99,
            'dryMatterKg': null,
            'ratio': null
          }
        ]
      },
    ]) {
      expect(() => FeedPlanRules.validate(FeedPlan.fromJson(broken)),
          throwsFormatException);
    }
    expect(() => FeedPlan.fromJson({...json, 'planType': 'future-evaluation'}),
        throwsFormatException);
  });

  test('Future plan type fails load and restore without changing disk/history',
      () async {
    final (e, c) = await environment();
    final plan = draft(e, c);
    await e.store.savePlan(plan);
    final broken = jsonDecode(e.disk!) as Map<String, dynamic>;
    ((broken['data'] as Map)['feedPlans'] as List).single['planType'] =
        'future-evaluation';
    final disk = e.disk;
    await expectLater(
        e.store.restoreBackup(jsonEncode(broken)), throwsFormatException);
    expect(e.disk, disk);
    expect(e.store.feedPlans.single.toJson(), plan.toJson());
    var writes = 0;
    final bad = FarmStore(
        read: () async => jsonEncode(broken),
        write: (_) async {
          writes++;
        });
    await bad.load();
    expect(bad.error, isNotNull);
    expect(writes, 0);
  });

  test(
      'New evaluation IDs are unique at the same clock; conflict cannot drop response or request',
      () async {
    final (e, c) = await environment();
    final a = draft(e, c), b = draft(e, c);
    expect(a.id, isNot(b.id));
    await e.store.savePlan(a);
    await e.store.savePlan(b);
    await e.store.savePlan(FeedPlan.fromJson(a.toJson()));
    expect(e.store.feedPlans, hasLength(2));
    final changed = FeedPlan.fromJson({
      ...a.toJson(),
      'nutritionSnapshot': {
        ...a.nutritionSnapshot!.toJson(),
        'response': {
          'warnings': ['changed']
        }
      }
    });
    final disk = e.disk;
    await expectLater(e.store.savePlan(changed), throwsStateError);
    expect(e.disk, disk);
  });
}
