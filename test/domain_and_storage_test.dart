import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sapiens_app/application/farm_controller.dart';
import 'package:sapiens_app/application/nutrition_context.dart';
import 'package:sapiens_app/data/backup_codec.dart';
import 'package:sapiens_app/data/farm_repository.dart';
import 'package:sapiens_app/domain/condition.dart';
import 'package:sapiens_app/domain/milk_metrics.dart';
import 'package:sapiens_app/domain/records.dart';
import 'package:sapiens_app/domain/value.dart';

import 'helpers/harness.dart';

void main() {
  Future<Harness> env(FarmMode mode) async {
    final h = Harness();
    addTearDown(h.dispose);
    await h.start(mode);
    return h;
  }

  for (final mode in FarmMode.values) {
    test(
        '${mode.name}: account mode inherited, initial weight required, round trip',
        () async {
      final h = await env(mode), c = await h.add();
      expect(c.weights, hasLength(1));
      expect(c.conditions, hasLength(1));
      expect(c.toJson().containsKey('production_category'), isFalse);
      final backup = h.controller.export();
      final decoded = BackupCodec.decode(backup);
      expect(decoded.account!.mode, mode);
      expect(decoded.find(c.id)!.latestWeight.kg, 300);
      final loaded = await FarmRepository(h.storage).load();
      expect(loaded.toJson(), h.data.toJson());
      final before = h.storage.raw;
      await expectLater(
          h.add(weight: WeightInput(kg: 0)), throwsFormatException);
      expect(h.storage.raw, before);
      expect(h.data.cattle, hasLength(1));
    });
    test(
        '${mode.name}: same clock IDs unique, concurrent creation retains both',
        () async {
      final h = await env(mode);
      await Future.wait([h.add(name: 'A'), h.add(name: 'B')]);
      expect(h.data.cattle, hasLength(2));
      final ids = h.data.cattle.expand((c) => [
            c.id,
            ...c.weights.map((r) => r.id),
            ...c.conditions.map((r) => r.id)
          ]);
      expect(ids.toSet().length, ids.length);
    });
    test('${mode.name}: failed write retains published state and disk',
        () async {
      final h = await env(mode), c = await h.add();
      final before = h.storage.raw;
      h.storage.fail = true;
      await expectLater(
          h.controller.addWeight(c.id, WeightInput(kg: 305),
              expectedWeight: c.latestWeight.id),
          throwsStateError);
      expect(h.storage.raw, before);
      expect(h.data.find(c.id)!.weights, hasLength(1));
      h.storage.fail = false;
      await h.controller.addWeight(c.id, WeightInput(kg: 305),
          expectedWeight: c.latestWeight.id);
      expect(h.data.find(c.id)!.weights, hasLength(2));
    });
  }
  test(
      'All weights/photos append, stale measurement and identity edits cannot erase newer history',
      () async {
    final h = await env(FarmMode.beef), c = await h.add();
    await h.controller.addWeight(c.id, WeightInput(kg: 310),
        expectedWeight: c.latestWeight.id);
    await h.controller.identity(c.id,
        name: 'Updated', userId: 'P-01', sex: c.sex, ageMonths: 25);
    expect(h.data.find(c.id)!.weights, hasLength(2));
    await expectLater(
        h.controller.addWeight(c.id, WeightInput(kg: 311),
            expectedWeight: c.latestWeight.id),
        throwsFormatException);
    expect(h.data.find(c.id)!.latestWeight.kg, 310);
    expect(() => h.data.cattle.clear(), throwsUnsupportedError);
  });
  test(
      'Nutrition response and nested context are immutable; evaluation is never active ration',
      () async {
    final h = await env(FarmMode.beef), c = await h.add();
    final e = await h.evaluate(c.id);
    expect(() => e.response['status'] = 'fake', throwsUnsupportedError);
    expect(
        () => (e.response['adequacy'] as Map).clear(), throwsUnsupportedError);
    expect(e.request['production_category'], 'beef');
    expect(e.contextSnapshot['condition'], c.condition.toJson());
    expect(e.feedNames['rumput_gajah'], 'Rumput gajah');
    expect(
        BackupCodec.decode(h.controller.export())
            .find(c.id)!
            .evaluations
            .single
            .toJson(),
        e.toJson());
  });
  test(
      'Weight, care and archive invalidate evaluation; name-only edit does not',
      () async {
    final h = await env(FarmMode.beef),
        c = await h.add(),
        e = await h.evaluate(c.id);
    bool current() =>
        NutritionContext(FarmMode.beef, h.data.find(c.id)!, h.now).isCurrent(e);
    expect(current(), isTrue);
    await h.controller.identity(c.id,
        name: 'New name', userId: '', sex: c.sex, ageMonths: c.ageMonths);
    expect(current(), isTrue);
    await h.controller.condition(
        c.id,
        const BeefCondition(
            purpose: BeefPurpose.fattening,
            phase: FatteningPhase.late,
            targetAdg: .5),
        expectedCondition: c.conditions.last.id);
    expect(current(), isFalse);
    expect(h.data.find(c.id)!.evaluations.single.id, e.id);
    await h.controller.archive(c.id, true);
    expect(h.data.active, isEmpty);
    expect(h.data.find(c.id)!.evaluations, hasLength(1));
    await h.controller.archive(c.id, false);
    expect(h.data.active, hasLength(1));
  });
  test('Unsupported breeding and dairy male never call generic nutrition',
      () async {
    final h = await env(FarmMode.beef),
        c = await h.add(
            condition: const BeefCondition(purpose: BeefPurpose.breeding));
    await expectLater(h.evaluate(c.id), throwsFormatException);
    expect(h.gateway.nutritionCalls, 0);
    final d = await env(FarmMode.dairy), male = await d.add(sex: Sex.male);
    await expectLater(d.evaluate(male.id), throwsFormatException);
    expect(d.gateway.nutritionCalls, 0);
  });
  test(
      'Milk uses one active mode per day, preserves partial values and corrections',
      () async {
    final h = await env(FarmMode.dairy), c = await h.add();
    await h.controller.milk(c.id,
        date: '2026-10-27', mode: MilkMode.amPm, unit: MilkUnit.kg, am: 8);
    var m = MilkMetrics(h.data.find(c.id)!, h.now);
    expect(m.latest!.complete, isFalse);
    expect(m.latest!.pm, isNull);
    expect(m.average(MilkUnit.kg, 7), isNull);
    final first = m.latest!.id;
    await h.controller.milk(c.id,
        date: '2026-10-27',
        mode: MilkMode.amPm,
        unit: MilkUnit.kg,
        am: 8,
        pm: 6,
        expectedCurrentId: first);
    m = MilkMetrics(h.data.find(c.id)!, h.now);
    expect(m.latest!.recordedAmount, 14);
    expect(m.average(MilkUnit.kg, 7), 14);
    await h.controller.milk(c.id,
        date: '2026-10-27',
        mode: MilkMode.totalDaily,
        unit: MilkUnit.kg,
        total: 15,
        expectedCurrentId: m.latest!.id);
    expect(h.data.find(c.id)!.milk, hasLength(3));
    expect(
        MilkMetrics(h.data.find(c.id)!, h.now).days.single.recordedAmount, 15);
    await expectLater(
        h.controller.milk(c.id,
            date: '2026-10-27',
            mode: MilkMode.totalDaily,
            unit: MilkUnit.kg,
            total: 16,
            expectedCurrentId: first),
        throwsFormatException);
  });
  test(
      'Dairy DIM/parity resets from actual calving; first unknown parity is not invented',
      () async {
    final h = await env(FarmMode.dairy), c = await h.add();
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.calving,
        date: '2026-10-01',
        parity: 1,
        expectedEventCount: 0);
    var m = MilkMetrics(h.data.find(c.id)!, h.now);
    expect(m.dim, 26);
    expect(m.parity, 1);
    h.now = DateTime.utc(2027, 10, 1, 12);
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.calving,
        date: '2027-10-01',
        expectedEventCount: 1);
    m = MilkMetrics(h.data.find(c.id)!, h.now);
    expect(m.dim, 0);
    expect(m.parity, 2);
    final unknown = await h.add(name: 'Unknown');
    await h.controller.dairyEvent(unknown.id,
        kind: DairyEventKind.calving,
        date: '2027-10-01',
        expectedEventCount: 0);
    expect(MilkMetrics(h.data.find(unknown.id)!, h.now).parity, isNull);
  });
  test(
      'Lactating request requires real DIM, kg milk, parity and fat; no liter conversion',
      () async {
    final h = await env(FarmMode.dairy), c = await h.lactating();
    final e = await h.evaluate(c.id), body = object(e.request['cattle']);
    expect(body['dairy_stage'], 'early_lactation');
    expect(body['dim'], 26);
    expect(body['milk_kg_day'], 15);
    expect(body['parity_group'], 'primiparous');
    final current = h.data.find(c.id)!;
    await h.controller.milk(c.id,
        date: '2026-10-27',
        mode: MilkMode.totalDaily,
        unit: MilkUnit.liter,
        total: 15,
        expectedCurrentId: current.milk.last.id);
    await expectLater(h.evaluate(c.id), throwsFormatException);
    expect(h.gateway.nutritionCalls, 1);
    expect(h.data.find(c.id)!.evaluations, hasLength(1));
  });
  test(
      'DIM zero and unsupported stages are explicit, never sent as guessed DIM one',
      () async {
    final h = await env(FarmMode.dairy),
        c = await h.add(
            condition: const DairyCondition(
                stage: DairyStage.fresh, parity: 1, milkFat: 3.8));
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.calving,
        date: '2026-10-27',
        parity: 1,
        expectedEventCount: 0);
    await h.controller.milk(c.id,
        date: '2026-10-27',
        mode: MilkMode.totalDaily,
        unit: MilkUnit.kg,
        total: 10);
    final ctx = NutritionContext(FarmMode.dairy, h.data.find(c.id)!, h.now);
    ctx.build();
    expect(ctx.issues.any((e) => e.contains('DIM 0')), isTrue);
    await expectLater(h.evaluate(c.id), throwsFormatException);
    expect(h.gateway.nutritionCalls, 0);
  });
  test('Withholding uses inclusive user dates only; pregnancy is manual',
      () async {
    final h = await env(FarmMode.dairy), c = await h.add();
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.pregnancyCheck,
        date: '2026-10-27',
        pregnancy: Pregnancy.uncertain,
        expectedEventCount: 0);
    await h.controller.dairyEvent(c.id,
        kind: DairyEventKind.withholding,
        date: '2026-10-27',
        until: '2026-10-29',
        note: 'Tanggal dari label',
        expectedEventCount: 1);
    expect(MilkMetrics(h.data.find(c.id)!, h.now).holds, hasLength(1));
    h.now = DateTime.utc(2026, 10, 29, 12);
    expect(MilkMetrics(h.data.find(c.id)!, h.now).holds, hasLength(1));
    h.now = DateTime.utc(2026, 10, 30, 12);
    expect(MilkMetrics(h.data.find(c.id)!, h.now).holds, isEmpty);
    expect(h.data.find(c.id)!.events.first.pregnancy, Pregnancy.uncertain);
  });
  test(
      'Mode switch requires confirmation and revision, clears every cattle history atomically',
      () async {
    final h = await env(FarmMode.beef), c = await h.add();
    await h.evaluate(c.id);
    final original = h.controller.export(), expected = h.data;
    await expectLater(
        h.controller
            .changeMode(FarmMode.dairy, expected: expected, confirmed: false),
        throwsFormatException);
    h.storage.fail = true;
    await expectLater(
        h.controller
            .changeMode(FarmMode.dairy, expected: expected, confirmed: true),
        throwsStateError);
    expect(h.controller.export(), original);
    h.storage.fail = false;
    await h.controller
        .changeMode(FarmMode.dairy, expected: expected, confirmed: true);
    expect(h.data.account!.mode, FarmMode.dairy);
    expect(h.data.cattle, isEmpty);
    final before = h.storage.raw;
    await expectLater(
        h.controller
            .changeMode(FarmMode.beef, expected: expected, confirmed: true),
        throwsFormatException);
    expect(h.storage.raw, before);
  });
  test(
      'Corrupt/newer/foreign backup and stale restore never write; valid backup restores',
      () async {
    final h = await env(FarmMode.beef);
    await h.add();
    final original = h.controller.export();
    for (final update in [
      {'schemaVersion': 99},
      {'application': 'old-app'},
      {'checksum': 'wrong'}
    ]) {
      final altered = jsonEncode({...object(jsonDecode(original)), ...update});
      final before = h.storage.raw;
      await expectLater(h.controller.restore(altered, expected: h.data),
          throwsFormatException);
      expect(h.storage.raw, before);
    }
    final expected = h.data;
    await h.add(name: 'Second');
    final before = h.storage.raw;
    await expectLater(h.controller.restore(original, expected: expected),
        throwsFormatException);
    expect(h.storage.raw, before);
    await h.controller.restore(original, expected: h.data);
    expect(h.data.cattle, hasLength(1));
  });
}
