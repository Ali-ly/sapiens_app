import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_api_v2.dart';
import 'package:sapita_app/screens/cattle/add_cattle_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_list_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_profile_screen.dart';
import 'package:sapita_app/screens/feed/feed_calculator_screen.dart';
import 'package:sapita_app/screens/feed/feed_hub_screen.dart';
import 'package:sapita_app/screens/feed/individual_feed_entry_screen.dart';
import 'package:sapita_app/screens/profile/farm_settings_screen.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/nutrition_fixture.dart';
import 'helpers/test_app.dart';

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);
  late FarmStore store;
  late Cattle beef, dairy, legacy;
  final calls = <ProductionCategory>[];

  Future<Cattle> add(String name, ProductionCategory? category) async {
    final c = await store.saveCattle(Cattle(
        nameOrId: name,
        gender: 'Betina',
        ageMonths: 24,
        productionCategory: category));
    await store.recordWeight(c.id, weightKg: 300, source: 'manual');
    if (category == ProductionCategory.beef) {
      await store.recordBeef(c.id,
          kind: BeefRecordKind.purpose,
          purpose: BeefPurpose.fattening,
          note: 'Explicit purpose');
    } else if (category == ProductionCategory.dairy) {
      await store.recordDairy(c.id,
          kind: DairyRecordKind.phase,
          day: '2026-10-27',
          phase: DairyPhase.fresh,
          note: 'Explicit stage');
    }
    return store.byId(c.id)!;
  }

  Future<void> setup(FarmProductionSystems? systems) async {
    calls.clear();
    store =
        FarmStore(read: () async => null, write: (_) async {}, now: () => now);
    await store.load();
    // This legacy Twin predates farm classification; do not infer its category.
    legacy = await add('Legacy Twin', null);
    if (systems != null) await store.configureProductionSystems(systems);
    if (systems == null || systems.allows(ProductionCategory.beef)) {
      beef = await add('Pedaging Twin', ProductionCategory.beef);
    }
    if (systems == null || systems.allows(ProductionCategory.dairy)) {
      dairy = await add('Perah Twin', ProductionCategory.dairy);
    }
    addTearDown(store.dispose);
  }

  Future<void> open(WidgetTester t,
      {String? cattleId,
      FeedCatalogLoader? loader,
      NutritionEvaluation? evaluate}) async {
    await t.pumpWidget(buildTestApp(
        store: store,
        home: IndividualFeedEntryScreen(
            cattleId: cattleId,
            now: () => now,
            loadFeeds: loader ??
                ({required productionCategory}) {
                  calls.add(productionCategory);
                  return loadNutritionCatalog(
                      productionCategory: productionCategory);
                },
            evaluate: evaluate ?? evaluateNutrition)));
    await t.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester t, Finder target,
      {double delta = 200}) async {
    await t.scrollUntilVisible(target, delta,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last,
        maxScrolls: 80);
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  Future<void> choose(WidgetTester t, ProductionCategory category) async {
    final choice = find.byKey(ValueKey('feed-domain-${category.name}'));
    await reveal(t, choice);
    await t.tap(choice);
    await t.pumpAndSettle();
  }

  Future<void> selectCow(WidgetTester t, String name) async {
    final dropdown = find.byKey(const ValueKey('nutrition-cattle'));
    await reveal(t, dropdown);
    await t.tap(dropdown);
    await t.pumpAndSettle();
    await t.tap(find.text(name).last);
    await t.pumpAndSettle();
  }

  testWidgets(
      'Hub chooses domain before showing individual cattle and carries it into the process',
      (t) async {
    await setup(FarmProductionSystems.both);
    await t.pumpWidget(buildTestApp(
        store: store,
        home: FeedHubScreen(loadFeeds: ({required productionCategory}) {
          calls.add(productionCategory);
          return loadNutritionCatalog(productionCategory: productionCategory);
        })));
    await t.pumpAndSettle();
    expect(find.text('Pedaging Twin'), findsNothing);
    expect(find.text('Perah Twin'), findsNothing);
    await t.tap(find.byKey(const ValueKey('feed-hub-domain-beef')));
    await t.pumpAndSettle();
    await reveal(t, find.text('Pedaging Twin'));
    expect(find.text('Perah Twin'), findsNothing);
    await reveal(t, find.text('Ganti jenis sapi'), delta: -200);
    await t.tap(find.text('Ganti jenis sapi'));
    await t.pumpAndSettle();
    await reveal(t, find.byKey(const ValueKey('feed-hub-domain-dairy')));
    await t.tap(find.byKey(const ValueKey('feed-hub-domain-dairy')));
    await t.pumpAndSettle();
    await reveal(t, find.text('Perah Twin'));
    expect(find.text('Pedaging Twin'), findsNothing);
    await reveal(t, find.text('Hitung pakan'));
    await t.tap(find.text('Hitung pakan'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<IndividualFeedEntryScreen>(
                find.byType(IndividualFeedEntryScreen))
            .initialCategory,
        ProductionCategory.dairy);
    expect(find.text('Pakan Sapi Perah'), findsOneWidget);
    expect(find.byKey(const ValueKey('feed-domain-dairy')), findsNothing);
    expect(calls, [ProductionCategory.dairy]);
  });

  testWidgets('Both requires domain choice even from a known cattle profile',
      (t) async {
    await setup(FarmProductionSystems.both);
    await open(t, cattleId: beef.id);
    expect(find.byType(FeedCalculatorScreen), findsNothing);
    expect(find.byKey(const ValueKey('feed-domain-beef')), findsOneWidget);
    await reveal(t, find.byKey(const ValueKey('feed-domain-dairy')));
    expect(find.byKey(const ValueKey('feed-domain-dairy')), findsOneWidget);
    expect(calls, isEmpty);
    await choose(t, ProductionCategory.beef);
    expect(find.text('Pakan Sapi Pedaging'), findsOneWidget);
    expect(calls, [ProductionCategory.beef]);
  });

  for (final category in ProductionCategory.values) {
    testWidgets(
        'Both ${category.name} filters active cattle and preserves legacy null',
        (t) async {
      await setup(FarmProductionSystems.both);
      final inactive = await add('Inactive Twin', category);
      await store.remove(inactive.id);
      await open(t);
      await choose(t, category);
      final dropdown = t.widget<DropdownButton<String>>(find.descendant(
          of: find.byKey(const ValueKey('nutrition-cattle')),
          matching: find.byType(DropdownButton<String>)));
      expect(dropdown.items!.map((item) => item.value),
          [category == ProductionCategory.beef ? beef.id : dairy.id]);
      expect(store.byId(legacy.id)!.productionCategory, isNull);
      expect(calls, isEmpty);
      await selectCow(t,
          category == ProductionCategory.beef ? 'Pedaging Twin' : 'Perah Twin');
      expect(calls, [category]);
    });

    testWidgets(
        'Single ${category.name} enters its context without choosing again',
        (t) async {
      await setup(category == ProductionCategory.beef
          ? FarmProductionSystems.beef
          : FarmProductionSystems.dairy);
      await open(t,
          cattleId: category == ProductionCategory.beef ? beef.id : dairy.id);
      expect(find.byKey(const ValueKey('feed-domain-beef')), findsNothing);
      expect(find.byKey(const ValueKey('feed-domain-dairy')), findsNothing);
      expect(find.text('Ganti jenis sapi'), findsNothing);
      expect(
          find.text(category == ProductionCategory.beef
              ? 'Konteks Pedaging · Beef'
              : 'Konteks Perah · Dairy'),
          findsOneWidget);
      expect(calls, [category]);
    });

    testWidgets(
        '${category.name} evaluation still sends the selected Twin context',
        (t) async {
      await setup(FarmProductionSystems.both);
      NutritionRequest? sent;
      await open(t, evaluate: ({required request}) async {
        sent = request;
        return evaluateNutrition(request: request);
      });
      await choose(t, category);
      await selectCow(t,
          category == ProductionCategory.beef ? 'Pedaging Twin' : 'Perah Twin');
      if (category == ProductionCategory.beef) {
        final adg = find.byKey(const ValueKey('nutrition-target-adg'));
        await reveal(t, adg);
        await t.enterText(adg, '0.5');
      }
      final ingredient = find.byKey(const ValueKey('feed-select-rumput_gajah'));
      await reveal(t, ingredient);
      await t.tap(ingredient);
      await t.pumpAndSettle();
      final amount = find.byKey(const ValueKey('feed-quantity-rumput_gajah'));
      await reveal(t, amount);
      await t.enterText(amount, '25');
      await reveal(t, find.text('Evaluasi nutrisi'));
      await t.tap(find.text('Evaluasi nutrisi'));
      await t.pumpAndSettle();
      expect(sent!.productionCategory, category);
      expect(sent!.cattle.bodyWeightKg, 300);
      expect(sent!.cattle.data.containsKey('milk_kg_day'), isFalse);
      expect(find.text('Hasil evaluasi nutrisi'), findsOneWidget);
      expect(store.feedPlans, isEmpty);
    });
  }

  testWidgets(
      'Switching domain drops cow, ingredients and an unfinished catalog',
      (t) async {
    await setup(FarmProductionSystems.both);
    final pending = Completer<FeedCatalogResponse>();
    await open(t, cattleId: beef.id, loader: ({required productionCategory}) {
      calls.add(productionCategory);
      return productionCategory == ProductionCategory.beef
          ? pending.future
          : loadNutritionCatalog(productionCategory: productionCategory);
    });
    await t.tap(find.byKey(const ValueKey('feed-domain-beef')));
    await t.pump();
    await t.ensureVisible(find.text('Ganti jenis sapi'));
    await t.tap(find.text('Ganti jenis sapi'));
    await t.pumpAndSettle();
    await choose(t, ProductionCategory.dairy);
    expect(calls, [ProductionCategory.beef]);
    await selectCow(t, 'Perah Twin');
    pending.complete(await loadNutritionCatalog(
        productionCategory: ProductionCategory.beef));
    await t.pumpAndSettle();
    expect(calls, [ProductionCategory.beef, ProductionCategory.dairy]);
    expect(find.text('Pakan Sapi Perah'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('feed-quantity-rumput_gajah')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Reclassifying a selected cow does not silently change domains',
      (t) async {
    await setup(FarmProductionSystems.both);
    await open(t, cattleId: beef.id);
    await choose(t, ProductionCategory.beef);
    await store.setProductionCategory(beef.id, ProductionCategory.dairy,
        reason: 'Explicit correction');
    await t.pumpAndSettle();
    expect(calls, [ProductionCategory.beef]);
    expect(find.text('Pakan Sapi Pedaging'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('feed-select-rumput_gajah')), findsNothing);
    expect(store.byId(beef.id)!.history, hasLength(1));
  });

  testWidgets(
      'Legacy farm is explicit and can open settings without inferring a domain',
      (t) async {
    await setup(null);
    await open(t, cattleId: beef.id);
    expect(calls, isEmpty);
    expect(find.byType(FeedCalculatorScreen), findsNothing);
    expect(store.productionSystems, isNull);
    await t.tap(find.text('Atur sistem produksi'));
    await t.pumpAndSettle();
    expect(find.byType(FarmSettingsScreen), findsOneWidget);
  });

  testWidgets('Changing farm from single to Both returns to explicit choice',
      (t) async {
    await setup(FarmProductionSystems.beef);
    await open(t, cattleId: beef.id);
    await store.configureProductionSystems(FarmProductionSystems.both);
    await t.pumpAndSettle();
    expect(find.byType(FeedCalculatorScreen), findsNothing);
    expect(find.byKey(const ValueKey('feed-domain-beef')), findsOneWidget);
    expect(calls, [ProductionCategory.beef]);
  });

  testWidgets(
      'Changing domain confirms before clearing entered feed; cancel preserves it',
      (t) async {
    await setup(FarmProductionSystems.both);
    await open(t, cattleId: beef.id);
    await choose(t, ProductionCategory.beef);
    final ingredient = find.byKey(const ValueKey('feed-select-rumput_gajah'));
    await reveal(t, ingredient);
    expect(find.text('rumput_gajah'), findsNothing);
    await t.tap(ingredient);
    await t.pumpAndSettle();
    final amount = find.byKey(const ValueKey('feed-quantity-rumput_gajah'));
    await reveal(t, amount);
    await t.enterText(amount, '25');
    await reveal(t, find.text('Ganti jenis sapi'), delta: -200);
    await t.tap(find.text('Ganti jenis sapi'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('feed-domain-change-cancel')));
    await t.pumpAndSettle();
    await reveal(t, amount);
    expect(t.widget<TextFormField>(amount).controller!.text, '25');
    await reveal(t, find.text('Ganti jenis sapi'), delta: -200);
    await t.tap(find.text('Ganti jenis sapi'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('feed-domain-change-confirm')));
    await t.pumpAndSettle();
    expect(find.byType(FeedCalculatorScreen), findsNothing);
    expect(store.byId(beef.id)!.history, hasLength(1));
    expect(store.feedPlans, isEmpty);
  });

  testWidgets('Empty Perah flow preselects the category when adding a cow',
      (t) async {
    await setup(FarmProductionSystems.both);
    await store.remove(dairy.id);
    await open(t);
    await choose(t, ProductionCategory.dairy);
    await reveal(t, find.text('Tambah sapi'));
    await t.tap(find.text('Tambah sapi'));
    await t.pumpAndSettle();
    expect(
        t.widget<AddCattleScreen>(find.byType(AddCattleScreen)).initialCategory,
        ProductionCategory.dairy);
    await t.enterText(find.byKey(const ValueKey('cattle-name')), 'Perah Baru');
    await t.enterText(find.byKey(const ValueKey('cattle-age')), '24');
    await reveal(t, find.text('Simpan sapi'));
    await t.tap(find.text('Simpan sapi'));
    await t.pumpAndSettle();
    expect(
        store.cattle
            .singleWhere((c) => c.nameOrId == 'Perah Baru')
            .productionCategory,
        ProductionCategory.dairy);
  });

  testWidgets(
      'Missing feed context has a direct action to complete the cattle profile',
      (t) async {
    await setup(FarmProductionSystems.beef);
    final c = await store.saveCattle(Cattle(
        nameOrId: 'Belum lengkap',
        gender: 'Jantan',
        ageMonths: 18,
        productionCategory: ProductionCategory.beef));
    await store.recordWeight(c.id, weightKg: 300, source: 'manual');
    await open(t, cattleId: c.id);
    await reveal(t, find.text('Lengkapi profil sapi'));
    await t.tap(find.text('Lengkapi profil sapi'));
    await t.pumpAndSettle();
    expect(find.byType(CattleProfileScreen), findsOneWidget);
    expect(store.byId(c.id)!.modules.beef?.purpose, isNull);
  });

  testWidgets(
      'Legacy classification action opens the unclassified cattle filter',
      (t) async {
    await setup(FarmProductionSystems.beef);
    await open(t);
    await reveal(t, find.text('Lengkapi kategori sapi lainnya'));
    await t.tap(find.text('Lengkapi kategori sapi lainnya'));
    await t.pumpAndSettle();
    expect(
        t.widget<CattleListScreen>(find.byType(CattleListScreen)).initialFilter,
        'Belum diklasifikasi');
    expect(store.byId(legacy.id)!.productionCategory, isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('Both domain entry fits width $width', (t) async {
      await setup(FarmProductionSystems.both);
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await open(t);
      await choose(t, ProductionCategory.dairy);
      expect(t.takeException(), isNull);
    });
  }
}
