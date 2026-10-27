import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sapiens_app/api/contracts.dart';
import 'package:sapiens_app/application/farm_controller.dart';
import 'package:sapiens_app/application/nutrition_context.dart';
import 'package:sapiens_app/application/providers.dart';
import 'package:sapiens_app/data/backup_codec.dart';
import 'package:sapiens_app/data/farm_repository.dart';
import 'package:sapiens_app/domain/condition.dart';
import 'package:sapiens_app/domain/milk_metrics.dart';
import 'package:sapiens_app/domain/records.dart';
import 'package:sapiens_app/domain/value.dart';
import 'helpers/harness.dart';
import 'helpers/live_fixtures.dart';

void main() {
  Future<Harness> env(FarmMode mode) async {
    final h = Harness();
    addTearDown(h.dispose);
    await h.start(mode);
    return h;
  }

  test('In-flight nutrition cannot save a stale context after a newer weight',
      () async {
    final h = await env(FarmMode.beef), c = await h.add();
    final started = Completer<void>(), response = Completer<Json>();
    h.gateway.respond = (_) {
      started.complete();
      return response.future;
    };
    final pending = h.evaluate(c.id);
    await started.future;
    final rejected = expectLater(pending, throwsFormatException);
    await h.controller.addWeight(c.id, WeightInput(kg: 310),
        expectedWeight: c.latestWeight.id);
    response.complete(beefResponse());
    await rejected;
    expect(h.data.find(c.id)!.evaluations, isEmpty);
    expect(h.data.find(c.id)!.weights, hasLength(2));
  });
  test(
      'Network error saves no placeholder result and retry retains input payload',
      () async {
    final h = await env(FarmMode.beef),
        c = await h.add(),
        before = h.storage.raw;
    h.gateway.respond =
        (_) async => throw const GatewayError('Offline', statusCode: 503);
    await expectLater(h.evaluate(c.id), throwsA(isA<GatewayError>()));
    expect(h.storage.raw, before);
    h.gateway.respond = null;
    await h.evaluate(c.id);
    expect(h.data.find(c.id)!.evaluations, hasLength(1));
    expect(h.gateway.lastRequest!['feed_items'], [
      {'feed_id': 'rumput_gajah', 'as_fed_kg_day': 25.0}
    ]);
  });
  test(
      'Photo estimate stores only accepted photos and retains all previous gallery/history',
      () async {
    final h = await env(FarmMode.beef), c = await h.add();
    final images = [
      UploadPhoto(name: 'valid.jpg', bytes: [1, 2, 3]),
      UploadPhoto(name: 'invalid.jpg', bytes: [4])
    ];
    final result = WeightEstimate.parse({
      'estimated_weight_kg': 310,
      'num_valid_images': 1,
      'rejected_files': ['invalid.jpg'],
      'prediction_spread_kg': 0
    }, images);
    await h.controller.addWeight(c.id, WeightInput.estimate(result),
        expectedWeight: c.latestWeight.id);
    var current = h.data.find(c.id)!;
    expect(current.photos.single.name, 'valid.jpg');
    expect(current.latestWeight.photoIds, [current.photos.single.id]);
    await h.controller.addPhotos(c.id, [
      UploadPhoto(name: 'gallery.jpg', bytes: [5, 6])
    ]);
    current = h.data.find(c.id)!;
    expect(current.photos, hasLength(2));
    expect(current.weights, hasLength(2));
    final copy = BackupCodec.decode(h.controller.export()).find(c.id)!;
    expect(copy.photos.first.bytes, [1, 2, 3]);
    expect(copy.photos.last.weightId, isNull);
  });
  test(
      'Dairy care events invalidate snapshots but never diagnose or change phase automatically',
      () async {
    final h = await env(FarmMode.dairy),
        c = await h.lactating(),
        evaluation = await h.evaluate(c.id);
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.pregnancyCheck,
        date: '2026-10-27',
        pregnancy: Pregnancy.uncertain,
        expectedEventCount: c.events.length);
    final current = h.data.find(c.id)!;
    expect(
        (current.condition as DairyCondition).stage, DairyStage.earlyLactation);
    expect(
        NutritionContext(FarmMode.dairy, current, h.now).isCurrent(evaluation),
        isFalse);
    expect(current.evaluations.single.id, evaluation.id);
  });
  test(
      'Milk averages preserve real zero, exclude partial days, separate units and bound window',
      () async {
    final h = await env(FarmMode.dairy), c = await h.add();
    await h.controller.milk(c.id,
        date: '2026-10-20',
        mode: MilkMode.totalDaily,
        unit: MilkUnit.kg,
        total: 100);
    await h.controller.milk(c.id,
        date: '2026-10-21',
        mode: MilkMode.totalDaily,
        unit: MilkUnit.kg,
        total: 0);
    await h.controller.milk(c.id,
        date: '2026-10-22', mode: MilkMode.amPm, unit: MilkUnit.kg, am: 8);
    await h.controller.milk(c.id,
        date: '2026-10-23',
        mode: MilkMode.totalDaily,
        unit: MilkUnit.liter,
        total: 20);
    await h.controller.milk(c.id,
        date: '2026-10-27',
        mode: MilkMode.totalDaily,
        unit: MilkUnit.kg,
        total: 10);
    final m = MilkMetrics(h.data.find(c.id)!, h.now);
    expect(m.average(MilkUnit.kg, 7), 5);
    expect(m.average(MilkUnit.liter, 7), 20);
    expect(m.average(MilkUnit.kg, 30), closeTo(110 / 3, .001));
  });
  test(
      'First-use load error does not create or overwrite storage; explicit restore recovers',
      () async {
    final h = await env(FarmMode.beef);
    await h.add();
    final good = h.controller.export();
    final storage = MemoryStorage()..raw = 'corrupt bytes';
    final repository = FarmRepository(storage);
    await expectLater(repository.load(), throwsFormatException);
    expect(storage.writes, 0);
    expect(storage.raw, 'corrupt bytes');
    final restored = await repository.restore(good);
    expect(restored.cattle, hasLength(1));
    expect(storage.writes, 1);
  });
  test(
      'Newer unknown fields with a recomputed checksum are rejected before write',
      () async {
    final h = await env(FarmMode.beef);
    await h.add();
    final j = object(jsonDecode(h.controller.export())),
        payload = object(j['payload']);
    payload['newFutureField'] = true;
    j['payload'] = payload;
    j['checksum'] = fingerprint(payload);
    final before = h.storage.raw;
    await expectLater(h.controller.restore(jsonEncode(j), expected: h.data),
        throwsFormatException);
    expect(h.storage.raw, before);
  });
  test(
      'Backdated pregnancy check cannot replace a newer check or carry across calving',
      () async {
    final h = await env(FarmMode.dairy);
    final c = await h.add();
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.pregnancyCheck,
        date: '2026-10-20',
        pregnancy: Pregnancy.uncertain,
        expectedEventCount: 0);
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.pregnancyCheck,
        date: '2026-10-10',
        pregnancy: Pregnancy.pregnant,
        expectedEventCount: 1);
    expect(
        MilkMetrics(h.data.find(c.id)!, h.now).latestPregnancyCheck!.pregnancy,
        Pregnancy.uncertain);
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.calving,
        date: '2026-10-25',
        expectedEventCount: 2);
    expect(MilkMetrics(h.data.find(c.id)!, h.now).latestPregnancyCheck, isNull);
    expect(h.data.find(c.id)!.events, hasLength(3));
  });
  test('New lactation cannot reuse milk recorded before its actual calving',
      () async {
    final h = await env(FarmMode.dairy);
    final c = await h.lactating();
    h.now = DateTime.utc(2026, 11, 1, 12);
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.calving,
        date: '2026-10-30',
        expectedEventCount: 1);
    final context = NutritionContext(FarmMode.dairy, h.data.find(c.id)!, h.now);
    context.build();
    expect(context.issues.any((s) => s.contains('setelah kelahiran terakhir')),
        isTrue);
    await expectLater(h.evaluate(c.id), throwsFormatException);
    expect(h.gateway.nutritionCalls, 0);
    expect(h.data.find(c.id)!.milk, hasLength(1));
    await h.controller.milk(c.id,
        date: '2026-11-01',
        mode: MilkMode.totalDaily,
        unit: MilkUnit.kg,
        total: 12);
    final ready = NutritionContext(FarmMode.dairy, h.data.find(c.id)!, h.now);
    final body = ready.build();
    expect(ready.issues, isEmpty);
    expect(body['milk_kg_day'], 12);
    expect(body['dim'], 2);
    expect(body['parity_group'], 'multiparous');
  });
  test('Production ID factory remains unique even while clock is identical',
      () async {
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 27)),
    ]);
    addTearDown(container.dispose);
    final ids = List.generate(1000, (_) => container.read(idProvider)());
    expect(ids.toSet(), hasLength(1000));
  });
  test('Product-specific and conditional reference feeds remain distinct', () {
    final conditional = FeedIngredient.fromJson({
      'feed_id': 'ref',
      'display_name': 'Reference',
      'valid_for': ['beef', 'future_domain'],
      'profile_status': 'conditional',
      'canonical_default': false
    });
    expect(conditional.productSpecific, isFalse);
    expect(conditional.validFor, [FarmMode.beef]);
    final specific = FeedIngredient.fromJson({
      'feed_id': 'product',
      'display_name': 'Product',
      'valid_for': ['dairy'],
      'profile_status': 'product_specific'
    });
    expect(specific.productSpecific, isTrue);
  });
}
