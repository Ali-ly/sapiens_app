// Opt-in live verification. Never included by `flutter test`'s test/ discovery.
// flutter test tool/live_individual_v2_test.dart --dart-define=RUN_LIVE_E2E=true
// Photo: --dart-define=E2E_COW_PHOTO=/absolute/path/public-cow.jpg
// Live service calls run before pumping widgets; inject those exact responses
// into the widget flow. This does not replace real browser/CORS verification.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_api_v2.dart';
import 'package:sapita_app/models/selected_image.dart';
import 'package:sapita_app/screens/feed/feed_calculator_screen.dart';
import 'package:sapita_app/screens/feed/feed_result_screen.dart';
import 'package:sapita_app/services/cattle_nutrition_context.dart';
import 'package:sapita_app/services/feed_service.dart';
import 'package:sapita_app/services/weight_service.dart';
import 'package:sapita_app/state/farm_store.dart';

import '../test/helpers/test_app.dart';

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_E2E');
  // Create the real TLS client before the widget binding's HTTP mock override.
  final client = live ? IOClient(HttpClient()) : null;
  tearDownAll(() => client?.close());
  final now = DateTime.now();
  final dir = Directory('/tmp/sapiens-step7');
  if (live) dir.createSync(recursive: true);
  Future<void> reveal(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 250,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last,
        maxScrolls: 150);
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  for (final category in ProductionCategory.values) {
    testWidgets(
        'LIVE ${category.name} catalog → evaluate → save → reload → history',
        (t) async {
      final file = File('${dir.path}/${category.name}-farm.json');
      String? disk;
      final store = FarmStore(
          read: () async => disk,
          write: (raw) async {
            disk = raw;
            file.writeAsStringSync(raw);
          },
          now: () => now);
      await store.load();
      var c = await store.saveCattle(Cattle(
          nameOrId: 'E2E ${category.name}',
          gender: 'Betina',
          ageMonths: 24,
          productionCategory: category));
      await store.recordWeight(c.id,
          weightKg: category == ProductionCategory.beef ? 300 : 500,
          source: 'manual');
      if (category == ProductionCategory.beef) {
        await store.recordBeef(c.id,
            kind: BeefRecordKind.purpose,
            purpose: BeefPurpose.fattening,
            note: 'Live test');
      } else {
        final birth = now.subtract(const Duration(days: 20));
        final day =
            '${birth.year}-${birth.month.toString().padLeft(2, '0')}-${birth.day.toString().padLeft(2, '0')}';
        await store.recordDairy(c.id,
            kind: DairyRecordKind.calving,
            day: day,
            parity: 2,
            note: 'Test calving');
        await store.recordDairy(c.id,
            kind: DairyRecordKind.phase,
            day: day,
            phase: DairyPhase.fresh,
            note: 'Manual test stage');
      }
      c = store.byId(c.id)!;
      final catalog = (await t.runAsync(() => FeedService.fetchFeeds(
          productionCategory: category, client: client)))!;
      var context = CattleNutritionContext.fromTwin(c, now);
      if (category == ProductionCategory.beef) {
        context = NutritionCattleContext.beef(
            bodyWeightKg: 300, purpose: 'penggemukan', targetAdgKgDay: 0.5);
      }
      final liveRequest = NutritionRequest(cattle: context, feedItems: [
        NutritionFeedItem(feedId: 'rumput_gajah', asFedKgDay: 25)
      ]);
      final response = (await t.runAsync(() => FeedService.calculateNutrition(
          request: liveRequest, client: client)))!;
      final sent = liveRequest.toJson(), received = response.toJson();
      File('${dir.path}/${category.name}-request.json')
          .writeAsStringSync(jsonEncode(sent));
      File('${dir.path}/${category.name}-flutter-response.json')
          .writeAsStringSync(jsonEncode(received));
      await t.pumpWidget(buildTestApp(
          store: store,
          home: FeedCalculatorScreen(
              cattleId: c.id,
              now: () => now,
              loadFeeds: ({required productionCategory}) async {
                expect(productionCategory, category);
                return catalog;
              },
              evaluate: ({required request}) async {
                expect(request.toJson(), sent);
                return response;
              })));
      await t.pumpAndSettle();
      if (category == ProductionCategory.beef) {
        final adg = find.byKey(const ValueKey('nutrition-target-adg'));
        await reveal(t, adg);
        await t.enterText(adg, '0.5');
      }
      final select = find.byKey(const ValueKey('feed-select-rumput_gajah'));
      await reveal(t, select);
      await t.tap(select);
      await t.pumpAndSettle();
      final quantity = find.byKey(const ValueKey('feed-quantity-rumput_gajah'));
      await reveal(t, quantity);
      await t.enterText(quantity, '25');
      await reveal(t, find.text('Evaluasi nutrisi'));
      await t.tap(find.text('Evaluasi nutrisi'));
      await t.pumpAndSettle();
      expect(find.text('Hasil evaluasi nutrisi'), findsOneWidget);
      expect(received, isNotNull);
      expect(sent['production_category'], category.name);
      if (category == ProductionCategory.beef) {
        expect(received['status'], 'ok');
        expect((sent['cattle'] as Map)['target_adg_kg_day'], 0.5);
      } else {
        expect((sent['cattle'] as Map).containsKey('milk_kg_day'), isFalse);
        expect(received['status'], 'insufficient_data');
      }
      await reveal(t, find.text('Simpan evaluasi'));
      await t.tap(find.text('Simpan evaluasi'));
      await t.pumpAndSettle();
      expect(store.feedPlans, hasLength(1));
      final saved = store.feedPlans.single;
      expect(saved.nutritionSnapshot!.response.toJson(), received);
      expect(saved.nutritionRequest!.toJson(), sent);
      final reloaded = FarmStore(
          read: () async => file.readAsStringSync(),
          write: (_) async {},
          now: () => now);
      await reloaded.load();
      expect(reloaded.error, isNull);
      expect(reloaded.feedPlans.single.toJson(), saved.toJson());
      final backup = FarmStore(
          read: () async => null, write: (_) async {}, now: () => now);
      await backup.load();
      await backup.restoreBackup(jsonEncode(reloaded.exportData()));
      expect(backup.feedPlans.single.toJson(), saved.toJson());
      expect(backup.byId(c.id)!.history, hasLength(1));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(buildTestApp(
          store: reloaded,
          home:
              FeedResultScreen(plan: reloaded.feedPlans.single, saved: true)));
      await t.pumpAndSettle();
      expect(find.text('Evaluasi tersimpan sebagai snapshot histori.'),
          findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      store.dispose();
      reloaded.dispose();
      backup.dispose();
    }, skip: !live);
  }

  test('LIVE Weight v2 public photo parses and appends weight/gallery',
      () async {
    const path = String.fromEnvironment('E2E_COW_PHOTO');
    expect(path, isNotEmpty);
    final bytes = await File(path).readAsBytes();
    final photo = SelectedImage(
        file: XFile(path), bytes: bytes, name: 'public-holstein.jpg');
    final estimate = await WeightService.predictWeight([photo], client: client);
    final store = FarmStore(read: () async => null, write: (_) async {});
    await store.load();
    final c = await store.saveCattle(
        Cattle(nameOrId: 'E2E Weight', gender: 'Betina', ageMonths: 24));
    await store.recordWeight(c.id, weightKg: 300, source: 'manual');
    await store.recordWeight(c.id,
        weightKg: estimate.weightKg,
        source: 'ai',
        images: [photo],
        predictionSpread: estimate.predictionSpread,
        validImages: estimate.validImages,
        rejectedImages: estimate.rejectedImages);
    expect(store.byId(c.id)!.history, hasLength(2));
    expect(store.byId(c.id)!.images.single.bytes, bytes);
    store.dispose();
  }, skip: !live);
}
