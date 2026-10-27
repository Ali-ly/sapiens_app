import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sapita_app/app.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_api_v2.dart';
import 'package:sapita_app/screens/feed/feed_calculator_screen.dart';
import 'package:sapita_app/screens/feed/feed_result_screen.dart';
import 'package:sapita_app/services/api_response.dart';
import 'package:sapita_app/services/feed_service.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/nutrition_fixture.dart';
import 'helpers/test_app.dart';

void main() {
  late FarmStore store;
  final now = DateTime.utc(2026, 10, 26, 12);
  Future<Cattle> setup(
      {ProductionCategory? category = ProductionCategory.beef}) async {
    store =
        FarmStore(read: () async => null, write: (_) async {}, now: () => now);
    await store.load();
    final c = await store.saveCattle(Cattle(
        nameOrId: 'Budi',
        gender: 'Betina',
        ageMonths: 18,
        productionCategory: category,
        estimatedWeight: 350,
        history: [WeightRecord(weightKg: 350, date: now, source: 'manual')]));
    if (category == ProductionCategory.beef) {
      await store.recordBeef(c.id,
          kind: BeefRecordKind.purpose,
          purpose: BeefPurpose.fattening,
          note: 'Recorded');
    }
    if (category == ProductionCategory.dairy) {
      await store.recordDairy(c.id,
          kind: DairyRecordKind.calving,
          day: '2026-10-01',
          note: 'Actual birth',
          parity: 2);
      await store.recordDairy(c.id,
          kind: DairyRecordKind.phase,
          day: '2026-10-26',
          note: 'Manual',
          phase: DairyPhase.fresh);
      await store.recordMilk(c.id,
          day: '2026-10-26', mode: MilkMode.daily, total: 12, note: 'Liters');
    }
    return store.byId(c.id)!;
  }

  Future<void> reveal(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last,
        maxScrolls: 50);
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  Future<void> choose(WidgetTester t,
      {String id = 'rumput_gajah', String amount = '25'}) async {
    final adg = find.byKey(const ValueKey('nutrition-target-adg'));
    if (store.cattle.first.modules.beef?.purpose == BeefPurpose.fattening) {
      await reveal(t, adg);
      await t.enterText(adg, '0.5');
    }
    final checkbox = find.byKey(ValueKey('feed-select-$id'));
    await reveal(t, checkbox);
    await t.tap(checkbox);
    await t.pumpAndSettle();
    final quantity = find.byKey(ValueKey('feed-quantity-$id'));
    await reveal(t, quantity);
    await t.enterText(quantity, amount);
    await reveal(t, find.text('Evaluasi nutrisi'));
  }

  Future<void> open(WidgetTester t, Cattle c,
      {FeedCatalogLoader? loader, NutritionEvaluation? evaluate}) async {
    await t.pumpWidget(buildTestApp(
        store: store,
        home: FeedCalculatorScreen(
            cattleId: c.id,
            loadFeeds: loader ?? loadNutritionCatalog,
            evaluate: evaluate ?? evaluateNutrition,
            now: () => now)));
    await t.pumpAndSettle();
  }

  for (final category in ProductionCategory.values) {
    testWidgets(
        '${category.name} individual uses GET catalog then POST nutrition from Twin, opens v2 result without automatically saving',
        (t) async {
      final c = await setup(category: category);
      final paths = <String>[];
      final client = MockClient((r) async {
        paths.add(r.url.path);
        if (r.method == 'GET') {
          expect(r.url.path, '/v2/feeds/${category.name}');
          return http.Response(
              jsonEncode(
                  (await loadNutritionCatalog(productionCategory: category))
                      .toJson()),
              200);
        }
        expect(r.url.path, '/v2/nutrition');
        final body = jsonDecode(r.body) as Map;
        expect(body['production_category'], category.name);
        expect(body['feed_items'], [
          {'feed_id': 'rumput_gajah', 'as_fed_kg_day': 25}
        ]);
        expect(
            body['cattle'],
            category == ProductionCategory.beef
                ? {
                    'body_weight_kg': 350,
                    'purpose': 'penggemukan',
                    'target_adg_kg_day': 0.5
                  }
                : {
                    'body_weight_kg': 350,
                    'dairy_stage': 'fresh',
                    'dim': 25,
                    'parity_group': 'multiparous'
                  });
        return http.Response(
            jsonEncode({
              'production_category': category.name,
              'coverage': {'status': 'partial'}
            }),
            200);
      });
      addTearDown(client.close);
      await open(t, c,
          loader: ({required productionCategory}) => FeedService.fetchFeeds(
              productionCategory: productionCategory, client: client),
          evaluate: ({required request}) =>
              FeedService.calculateNutrition(request: request, client: client));
      expect(find.text('Apa target pemeliharaannya?'), findsNothing);
      expect(find.text('Kondisi tubuh'), findsNothing);
      await choose(t);
      await t.tap(find.text('Evaluasi nutrisi'));
      await t.pumpAndSettle();
      expect(paths, ['/v2/feeds/${category.name}', '/v2/nutrition']);
      expect(find.text('Hasil evaluasi nutrisi'), findsOneWidget);
      expect(find.byType(FeedResultScreen), findsOneWidget);
      expect(store.feedPlans, isEmpty);
    });
  }

  testWidgets(
      'Fattening requires explicit valid evaluation ADG without a default',
      (t) async {
    final c = await setup();
    var calls = 0;
    await open(t, c, evaluate: ({required request}) async {
      calls++;
      expect(request.cattle.data['target_adg_kg_day'], 0.5);
      return evaluateNutrition(request: request);
    });
    await choose(t);
    final adg = find.byKey(const ValueKey('nutrition-target-adg'));
    for (final value in ['', '0', '-1', 'NaN', 'Infinity']) {
      await reveal(t, adg);
      await t.enterText(adg, value);
      await reveal(t, find.text('Evaluasi nutrisi'));
      await t.tap(find.text('Evaluasi nutrisi'));
      await t.pumpAndSettle();
      expect(calls, 0);
      expect(store.feedPlans, isEmpty);
    }
    await reveal(t, adg);
    await t.enterText(adg, '0,5');
    await reveal(t, find.text('Evaluasi nutrisi'));
    await t.tap(find.text('Evaluasi nutrisi'));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Hasil evaluasi nutrisi'), findsOneWidget);
  });

  testWidgets('Unmapped Dairy phase cannot submit nutrition request',
      (t) async {
    final c = await setup(category: ProductionCategory.dairy);
    await store.recordDairy(c.id,
        kind: DairyRecordKind.phase,
        day: '2026-10-26',
        phase: DairyPhase.calving,
        note: 'Manual transition');
    var calls = 0;
    await open(t, c, evaluate: ({required request}) async {
      calls++;
      return evaluateNutrition(request: request);
    });
    await reveal(t, find.text('Evaluasi nutrisi'));
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Evaluasi nutrisi'))
            .onPressed,
        isNull);
    expect(calls, 0);
    await reveal(t, find.textContaining('belum memiliki padanan'));
    expect(find.textContaining('belum memiliki padanan'), findsOneWidget);
  });

  testWidgets(
      'Null legacy category is not inferred; explicit Twin classification reloads catalog',
      (t) async {
    final c = await setup(category: null);
    var calls = 0;
    await open(t, c, loader: ({required productionCategory}) {
      calls++;
      return loadNutritionCatalog(productionCategory: productionCategory);
    });
    expect(find.textContaining('Klasifikasikan kategori'), findsOneWidget);
    expect(calls, 0);
    await store.setProductionCategory(c.id, ProductionCategory.beef,
        reason: 'Classified by owner');
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Catat tujuan Beef'), findsOneWidget);
    await store.recordBeef(c.id,
        kind: BeefRecordKind.purpose,
        purpose: BeefPurpose.breeding,
        note: 'Explicit purpose');
    await t.pumpAndSettle();
    expect(find.textContaining('Catat tujuan Beef'), findsNothing);
  });

  testWidgets(
      'Selected quantities must be positive finite numbers; decimal comma is supported',
      (t) async {
    final c = await setup();
    var calls = 0;
    await open(t, c, evaluate: ({required request}) async {
      calls++;
      expect(request.feedItems.single.asFedKgDay, 2.5);
      return evaluateNutrition(request: request);
    });
    await reveal(t, find.text('Evaluasi nutrisi'));
    await t.tap(find.text('Evaluasi nutrisi'));
    await t.pumpAndSettle();
    expect(find.textContaining('Pilih minimal satu bahan'), findsOneWidget);
    await choose(t, amount: '');
    for (final amount in ['', '0', '-2', 'NaN', 'Infinity', 'abc']) {
      await reveal(t, find.byKey(const ValueKey('feed-quantity-rumput_gajah')));
      await t.enterText(
          find.byKey(const ValueKey('feed-quantity-rumput_gajah')), amount);
      await reveal(t, find.text('Evaluasi nutrisi'));
      await t.tap(find.text('Evaluasi nutrisi'));
      await t.pumpAndSettle();
      expect(calls, 0);
    }
    await reveal(t, find.byKey(const ValueKey('feed-quantity-rumput_gajah')));
    await t.enterText(
        find.byKey(const ValueKey('feed-quantity-rumput_gajah')), '2,5');
    await reveal(t, find.text('Evaluasi nutrisi'));
    await t.tap(find.text('Evaluasi nutrisi'));
    await t.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets(
      'Catalog failure retries, empty catalog does not enable submission',
      (t) async {
    final c = await setup();
    var calls = 0;
    await open(t, c, loader: ({required productionCategory}) async {
      if (++calls == 1) throw const ApiException('Catalog offline');
      return FeedCatalogResponse.fromJson({
        'production_category': productionCategory.name,
        'count': 0,
        'feeds': []
      });
    });
    expect(find.textContaining('Catalog offline'), findsOneWidget);
    await reveal(t, find.text('Coba muat bahan lagi'));
    await t.tap(find.text('Coba muat bahan lagi'));
    await t.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('belum memiliki bahan'), findsOneWidget);
    await reveal(t, find.text('Evaluasi nutrisi'));
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Evaluasi nutrisi'))
            .onPressed,
        isNull);
  });

  testWidgets(
      'Backend rejection is shown without legacy fallback or plan persistence',
      (t) async {
    final c = await setup();
    var calls = 0;
    await open(t, c, evaluate: ({required request}) async {
      calls++;
      throw const ApiException('Dairy context unsupported', statusCode: 422);
    });
    await choose(t);
    await t.tap(find.text('Evaluasi nutrisi'));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Dairy context unsupported'), findsOneWidget);
    expect(find.text('Hasil evaluasi nutrisi'), findsNothing);
    expect(store.feedPlans, isEmpty);
  });

  testWidgets(
      'Changed Twin during evaluation rejects stale reply and duplicate tap',
      (t) async {
    final c = await setup();
    final reply = Completer<NutritionResponse>();
    var calls = 0;
    await open(t, c, evaluate: ({required request}) {
      calls++;
      return reply.future;
    });
    await choose(t);
    await t.tap(find.text('Evaluasi nutrisi'));
    await t.pump();
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Mengirim evaluasi…'))
            .onPressed,
        isNull);
    await store.recordWeight(c.id, weightKg: 400, source: 'manual');
    await t.pump();
    reply.complete(NutritionResponse.fromJson({'production_category': 'beef'}));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Data sapi berubah'), findsOneWidget);
    expect(find.text('Hasil evaluasi nutrisi'), findsNothing);
    expect(store.feedPlans, isEmpty);
  });

  testWidgets(
      'Late catalog from previous cow cannot replace the selected category',
      (t) async {
    final beef = await setup();
    final dairy = await store.saveCattle(Cattle(
        nameOrId: 'Dairy',
        gender: 'Betina',
        ageMonths: 18,
        productionCategory: ProductionCategory.dairy));
    final first = Completer<FeedCatalogResponse>();
    final second = Completer<FeedCatalogResponse>();
    await t.pumpWidget(buildTestApp(
        store: store,
        home: FeedCalculatorScreen(
            cattleId: beef.id,
            now: () => now,
            loadFeeds: ({required productionCategory}) =>
                productionCategory == ProductionCategory.beef
                    ? first.future
                    : second.future)));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('nutrition-cattle')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Dairy').last);
    await t.pump(const Duration(milliseconds: 400));
    second.complete(FeedCatalogResponse.fromJson({
      'production_category': 'dairy',
      'count': 1,
      'feeds': [
        {'feed_id': 'dairy_feed', 'display_name': 'Dairy catalog'}
      ]
    }));
    await t.pumpAndSettle();
    first.complete(await loadNutritionCatalog(
        productionCategory: ProductionCategory.beef));
    await t.pumpAndSettle();
    await reveal(t, find.text('Dairy catalog'));
    expect(find.text('Dairy catalog'), findsOneWidget);
    expect(find.text('Rumput gajah'), findsNothing);
    expect(store.byId(dairy.id)!.productionCategory, ProductionCategory.dairy);
    expect(t.takeException(), isNull);
  });

  testWidgets('Inactive cattle do not load catalog or submit', (t) async {
    final c = await setup();
    await store.remove(c.id);
    var calls = 0;
    await open(t, c, loader: ({required productionCategory}) {
      calls++;
      return loadNutritionCatalog(productionCategory: productionCategory);
    });
    expect(calls, 0);
    await reveal(t, find.textContaining('Sapi nonaktif'));
    expect(find.textContaining('Sapi nonaktif'), findsOneWidget);
  });

  testWidgets(
      'Reclassification reloads category catalog and clears old quantities',
      (t) async {
    final c = await setup();
    final categories = <ProductionCategory>[];
    await open(t, c, loader: ({required productionCategory}) {
      categories.add(productionCategory);
      return loadNutritionCatalog(productionCategory: productionCategory);
    });
    await choose(t);
    await store.setProductionCategory(c.id, ProductionCategory.dairy,
        reason: 'User correction');
    await store.recordDairy(c.id,
        kind: DairyRecordKind.phase,
        day: '2026-10-26',
        phase: DairyPhase.fresh,
        note: 'Manual stage');
    await t.pumpAndSettle();
    expect(categories, [ProductionCategory.beef, ProductionCategory.dairy]);
    expect(
        find.byKey(const ValueKey('feed-quantity-rumput_gajah')), findsNothing);
    expect(store.byId(c.id)!.modules.beef!.purpose, BeefPurpose.fattening);
  });

  testWidgets(
      'Leaving while catalog loads ignores late response without state errors',
      (t) async {
    final c = await setup();
    final reply = Completer<FeedCatalogResponse>();
    await t.pumpWidget(buildTestApp(
        store: store,
        home: FeedCalculatorScreen(
            cattleId: c.id,
            loadFeeds: ({required productionCategory}) => reply.future)));
    await t.pump();
    await t.pumpWidget(const SizedBox());
    reply.complete(await loadNutritionCatalog(
        productionCategory: ProductionCategory.beef));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('v2 ingredient entry fits width $width', (t) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = await setup(category: ProductionCategory.dairy);
      await open(t, c);
      await choose(t);
      expect(t.takeException(), isNull);
    });
  }
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'All four main tabs build without overflow at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        store = FarmStore(read: () async => null, write: (_) async {});
        await store.load();
        await store.addExamples();
        await store.configureProductionSystems(FarmProductionSystems.beef);
        await tester.pumpWidget(SapiensApp(store: store));
        await tester.pumpAndSettle();
        for (final label in ['Ternak', 'Pakan', 'Profil', 'Ringkasan']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
