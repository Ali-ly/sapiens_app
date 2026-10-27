import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/data/farm_backup_codec.dart';
import 'package:sapita_app/data/twin_codec.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/dairy/dairy_calendar.dart';
import 'package:sapita_app/models/dairy/dairy_metrics.dart';
import 'package:sapita_app/models/farm_command_center.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/dairy_environment.dart';
import 'helpers/legacy_feed_plan_fixture.dart';
import 'helpers/migration_fixtures.dart';

void main() {
  late DairyEnvironment e;
  setUp(() async {
    e = DairyEnvironment();
    await e.store.load();
  });
  tearDown(() => e.store.dispose());
  Future<void> milk(String id, String day, double liters, {String? old}) =>
      e.store.recordMilk(id,
          day: day,
          mode: MilkMode.daily,
          total: liters,
          note: 'Pencatatan pengguna',
          supersedesId: old);
  test(
      'A later-dated service stays in the new cycle when the actual calving is entered retrospectively',
      () async {
    final c = await e.add('Boundary');
    await e.birth(c.id, '2026-10-01');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service,
        day: '2026-10-25',
        note: 'Actual later service');
    final service = e.store.byId(c.id)!.modules.dairy!.records.last;
    await e.birth(c.id, '2026-10-20');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.pregnancy,
        day: '2026-10-26',
        relatedId: service.id,
        pregnancy: PregnancyResult.positive,
        confirmedConception: true,
        note: 'Confirmed service');
    final m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.daysOpen, 5);
    expect(m.servicesPerConception, 1);
  });
  test(
      'Calving closes pre-existing same-day breeding even without a linked check',
      () async {
    final c = await e.add('Boundary');
    await e.birth(c.id, '2026-10-01');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service,
        day: '2026-10-26',
        note: 'Before calving');
    final service = e.store.byId(c.id)!.modules.dairy!.records.last;
    await e.birth(c.id, '2026-10-26');
    final before = e.disk;
    await expectLater(
        e.store.recordDairy(c.id,
            kind: DairyRecordKind.pregnancy,
            day: '2026-10-26',
            relatedId: service.id,
            pregnancy: PregnancyResult.positive,
            confirmedConception: true,
            note: 'Old service reuse'),
        throwsFormatException);
    expect(e.disk, before);
  });
  test(
      'Same-day service after calving belongs to the new cycle; earlier service is excluded',
      () async {
    final c = await e.add('Boundary');
    await e.birth(c.id, '2026-10-01');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service,
        day: '2026-10-26',
        note: 'Before calving');
    await e.birth(c.id, '2026-10-26');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service,
        day: '2026-10-26',
        note: 'After calving');
    final service = e.store.byId(c.id)!.modules.dairy!.records.last;
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.pregnancy,
        day: '2026-10-26',
        relatedId: service.id,
        pregnancy: PregnancyResult.positive,
        confirmedConception: true,
        note: 'Confirmed new cycle');
    final m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.daysOpen, 0);
    expect(m.servicesPerConception, 1);
    expect(m.dim, 0);
  });
  test(
      'Closed-cycle metrics retain its same-day pre-calving service without attributing it to the next cycle',
      () async {
    final c = await e.add('Boundary');
    await e.birth(c.id, '2026-10-01');
    final first = e.store.byId(c.id)!.modules.dairy!.calvings.single;
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service,
        day: '2026-10-26',
        note: 'Before calving');
    final service = e.store.byId(c.id)!.modules.dairy!.records.last;
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.pregnancy,
        day: '2026-10-26',
        relatedId: service.id,
        pregnancy: PregnancyResult.positive,
        confirmedConception: true,
        note: 'Recorded confirmation');
    final check = e.store.byId(c.id)!.modules.dairy!.records.last;
    await e.birth(c.id, '2026-10-26', relatedId: check.id);
    final old = DairyMetrics(e.store.byId(c.id)!, e.now, cycleId: first.id),
        current = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(old.daysOpen, 25);
    expect(old.servicesPerConception, 1);
    expect(current.daysOpen, isNull);
    expect(current.servicesPerConception, isNull);
  });
  test(
      'A future-start hold correction replaces the old window as an explicit user correction',
      () async {
    final c = await e.add('Window');
    await milk(c.id, '2026-10-26', 20);
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.withholding,
        day: '2026-10-20',
        safeUseDay: '2026-10-30',
        note: 'Old');
    final old = e.store.byId(c.id)!.modules.dairy!.records.last;
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.withholding,
        day: '2026-10-27',
        safeUseDay: '2026-10-29',
        supersedesId: old.id,
        note: 'User correction');
    final m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.heldToday, isFalse);
    expect(m.today!.withheldLiters, 0);
    expect(m.activeHolds.single.day, '2026-10-27');
  });
  test(
      'Seven/thirty-day averages use inclusive current-day windows and complete-day coverage',
      () async {
    final c = await e.add('Window');
    for (final pair in [
      ('2026-09-26', 100.0),
      ('2026-09-27', 20.0),
      ('2026-10-19', 30.0),
      ('2026-10-20', 40.0)
    ]) {
      await milk(c.id, pair.$1, pair.$2);
    }
    await e.store.recordMilk(c.id,
        day: '2026-10-26', mode: MilkMode.amPm, am: 10, note: 'Partial');
    final m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.average, 47.5);
    expect(m.averageWindow(7), 40);
    expect(m.averageWindow(30), 30);
    expect(m.completeWindow(7).length, 1);
    expect(m.completeWindow(30).length, 3);
    final missing = await e.add('No records');
    expect(DairyMetrics(missing, e.now).averageWindow(7), isNull);
  });
  test('Every Dairy phase appends manual history, no DOB or cycle inferred',
      () async {
    final c = await e.add('Dara');
    for (final p in DairyPhase.values) {
      await e.store.recordDairy(c.id,
          kind: DairyRecordKind.phase,
          day: '2026-10-26',
          note: 'Fase manual',
          phase: p);
      expect(e.store.byId(c.id)!.modules.dairy!.phase, p);
    }
    final d = e.store.byId(c.id)!.modules.dairy!;
    expect(d.records.length, DairyPhase.values.length);
    expect(d.calvings, isEmpty);
    expect(e.store.byId(c.id)!.ageMonths, 18);
    expect(e.store.byId(c.id)!.core.identity.ageEvidence.birthDate, isNull);
    expect(() => d.records.clear(), throwsUnsupportedError);
    await e.store.load();
    expect(e.store.byId(c.id)!.modules.dairy!.records.length,
        DairyPhase.values.length);
  });
  test('Fresh/Early and Dry/CloseUp remain distinct, stages do not reset DIM',
      () async {
    final c = await e.add('Cow');
    await e.birth(c.id, '2026-10-01');
    for (final p in [
      DairyPhase.fresh,
      DairyPhase.early,
      DairyPhase.dry,
      DairyPhase.closeUp
    ]) {
      await e.store.recordDairy(c.id,
          kind: DairyRecordKind.phase,
          day: '2026-10-26',
          note: 'Manual',
          phase: p);
      expect(e.store.byId(c.id)!.modules.dairy!.phase, p);
      expect(DairyMetrics(e.store.byId(c.id)!, e.now).dim, 25);
    }
    expect(e.store.byId(c.id)!.modules.dairy!.calvings.length, 1);
  });
  test(
      'Daily total and AM/PM correction never double count, missing session remains partial',
      () async {
    final c = await e.add('Milk');
    await e.store.recordMilk(c.id,
        day: '2026-10-26', mode: MilkMode.amPm, am: 10, note: 'AM');
    var m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.today!.liters, 10);
    expect(m.today!.record.complete, isFalse);
    expect(m.average, isNull);
    final first = m.today!.record;
    await e.store.recordMilk(c.id,
        day: first.day,
        mode: MilkMode.amPm,
        am: 10,
        pm: 8,
        note: 'Tambah PM',
        supersedesId: first.id);
    m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.today!.liters, 18);
    expect(m.average, 18);
    expect(m.milk.length, 1);
    await milk(c.id, first.day, 19, old: m.today!.record.id);
    m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.today!.liters, 19);
    expect(e.store.byId(c.id)!.modules.dairy!.milk.length, 3);
    expect(e.store.dairyMilk.liters, 19);
  });
  test('Duplicate day, wrong correction chain and mixed modes fail atomically',
      () async {
    final c = await e.add('Milk');
    await milk(c.id, '2026-10-25', 20);
    final old = e.store.byId(c.id)!.modules.dairy!.milk.last;
    await milk(c.id, '2026-10-25', 21, old: old.id);
    final before = e.disk;
    for (final op in [
      () => milk(c.id, '2026-10-25', 22),
      () => milk(c.id, '2026-10-25', 22, old: old.id),
      () => milk(c.id, '2026-10-24', 22, old: old.id),
      () => e.store.recordMilk(c.id,
          day: '2026-10-26',
          mode: MilkMode.daily,
          total: 10,
          am: 10,
          note: 'Mixed')
    ]) {
      await expectLater(op(), throwsFormatException);
      expect(e.disk, before);
    }
  });
  for (final v in [-1.0, double.nan, double.infinity]) {
    test('Invalid milk volume $v rejected', () async {
      final c = await e.add('Cow');
      final before = e.disk;
      await expectLater(milk(c.id, '2026-10-26', v), throwsFormatException);
      expect(e.disk, before);
    });
  }
  test(
      'Explicit zero is complete; empty AM/PM and absent total are not fabricated zero',
      () async {
    final c = await e.add('Cow');
    await milk(c.id, '2026-10-25', 0);
    expect(DairyMetrics(e.store.byId(c.id)!, e.now).average, 0);
    await expectLater(
        e.store.recordMilk(c.id,
            day: '2026-10-26', mode: MilkMode.amPm, note: 'Empty'),
        throwsFormatException);
    await expectLater(
        e.store.recordMilk(c.id,
            day: '2026-10-26', mode: MilkMode.daily, note: 'Empty'),
        throwsFormatException);
  });
  test(
      'Average/trend denominator only complete observed days, peak actual cycle data',
      () async {
    final c = await e.add('Cow');
    await e.birth(c.id, '2026-10-01');
    await milk(c.id, '2026-10-02', 12);
    await milk(c.id, '2026-10-10', 20);
    await e.store.recordMilk(c.id,
        day: '2026-10-26', mode: MilkMode.amPm, am: 7, note: 'Partial');
    final m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.milk.length, 3);
    expect(m.completeDays.length, 2);
    expect(m.average, 16);
    expect(m.trendDelta, 8);
    expect(m.trendGapDays, 8);
    expect(m.latest!.record.complete, isFalse);
    expect(m.peak!.liters, 20);
    expect(m.curve.length, 2);
  });
  test('Milk without known calving has no DIM/curve or invented parity',
      () async {
    final c = await e.add('Unknown');
    await milk(c.id, '2026-10-26', 12);
    final m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.dim, isNull);
    expect(m.cycle, isNull);
    expect(m.peak, isNull);
    expect(m.curve, isEmpty);
  });
  test(
      'Large finite milk values keep a finite average; overflowing herd total is rejected',
      () async {
    final c = await e.add('Cow');
    await milk(c.id, '2026-10-25', 1e308);
    await milk(c.id, '2026-10-26', 1e308);
    expect(DairyMetrics(e.store.byId(c.id)!, e.now).average, 1e308);
    final other = await e.add('Other');
    final before = e.disk;
    await expectLater(
        milk(other.id, '2026-10-26', 1e308), throwsFormatException);
    expect(e.disk, before);
  });
  test(
      'Concurrent duplicate calving cannot double parity and category changes preserve Dairy history',
      () async {
    final c = await e.add('Cow');
    await e.birth(c.id, '2026-10-01', parity: 1);
    final a = e.birth(c.id, '2026-10-26'), b = e.birth(c.id, '2026-10-26');
    await a;
    await expectLater(b, throwsFormatException);
    expect(e.store.byId(c.id)!.modules.dairy!.calvings.last.parity, 2);
    final data = jsonEncode(e.store.byId(c.id)!.modules.dairy!.toJson());
    await e.store.configureProductionSystems(FarmProductionSystems.both);
    await e.store.setProductionCategory(c.id, ProductionCategory.beef,
        reason: 'Perubahan pengguna');
    expect(jsonEncode(e.store.byId(c.id)!.modules.dairy!.toJson()), data);
    await expectLater(milk(c.id, '2026-10-26', 10), throwsStateError);
  });
  test(
      'Calving is cycle start, DIM day zero, parity unknown stays unknown until explicit baseline',
      () async {
    final c = await e.add('Cow');
    await e.birth(c.id, '2026-09-01');
    await e.birth(c.id, '2026-10-01');
    expect(e.store.byId(c.id)!.modules.dairy!.calvings.last.parity, isNull);
    await e.birth(c.id, '2026-10-26', parity: 5);
    var m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.dim, 0);
    expect(m.cycle!.parity, 5);
    e.now = DateTime.utc(2026, 11, 1, 12);
    await e.birth(c.id, '2026-11-01');
    m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.dim, 0);
    expect(m.cycle!.parity, 6);
    expect(m.calvingInterval, 6);
  });
  test(
      'Calving never duplicates same day, regresses date, or overrides known parity',
      () async {
    final c = await e.add('Cow');
    await e.birth(c.id, '2026-10-01', parity: 3);
    final before = e.disk;
    for (final op in [
      () => e.birth(c.id, '2026-10-01'),
      () => e.birth(c.id, '2026-09-30'),
      () => e.birth(c.id, '2026-10-26', parity: 3)
    ]) {
      await expectLater(op(), throwsFormatException);
      expect(e.disk, before);
    }
    await e.birth(c.id, '2026-10-26');
    expect(e.store.byId(c.id)!.modules.dairy!.calvings.last.parity, 4);
  });
  test(
      'Calendar DIM arithmetic is independent of DST/24-hour duration and validates dates',
      () {
    expect(DairyCalendar.days('2026-03-28', '2026-03-30'), 2);
    expect(DairyCalendar.days('2024-02-28', '2024-03-01'), 2);
    expect(() => DairyCalendar.parse('2026-02-31'), throwsFormatException);
    expect(() => DairyCalendar.parse('2026-10-26T00:00:00Z'),
        throwsFormatException);
  });
  test(
      'Reproduction service/check/calving preserves references and closes the cycle atomically',
      () async {
    final dam = await e.add('Dam'),
        sire = await e.add('Sire', gender: 'Jantan'),
        calf = await e.add('Calf');
    await e.birth(dam.id, '2026-08-01', parity: 1);
    await e.store.recordDairy(dam.id,
        kind: DairyRecordKind.service,
        day: '2026-08-20',
        sireId: sire.id,
        note: 'IB');
    final service = e.store.byId(dam.id)!.modules.dairy!.records.last;
    await e.store.recordDairy(dam.id,
        kind: DairyRecordKind.pregnancy,
        day: '2026-09-20',
        relatedId: service.id,
        pregnancy: PregnancyResult.positive,
        confirmedConception: true,
        note: 'Pengguna konfirmasi');
    final check = e.store.byId(dam.id)!.modules.dairy!.records.last;
    final firstCycle = e.store.byId(dam.id)!.modules.dairy!.calvings.first;
    var m = DairyMetrics(e.store.byId(dam.id)!, e.now);
    expect(m.daysOpen, 19);
    expect(m.servicesPerConception, 1);
    await e.birth(dam.id, '2026-10-26', relatedId: check.id, calfId: calf.id);
    m = DairyMetrics(e.store.byId(dam.id)!, e.now);
    expect(m.dim, 0);
    expect(m.cycle!.parity, 2);
    expect(m.calvingInterval, 86);
    expect(m.daysOpen, isNull);
    expect(e.store.byId(calf.id)!.core.references.damId, dam.id);
    expect(e.store.byId(calf.id)!.core.references.sireId, sire.id);
    expect(e.store.byId(calf.id)!.ageMonths, 18);
    final old =
        DairyMetrics(e.store.byId(dam.id)!, e.now, cycleId: firstCycle.id);
    expect(old.daysOpen, 19);
    expect(old.servicesPerConception, 1);
    expect(old.dim, isNull);
    final before = e.disk;
    e.now = e.now.add(const Duration(days: 1));
    await expectLater(e.birth(dam.id, '2026-10-27', relatedId: check.id),
        throwsFormatException);
    expect(e.disk, before);
  });
  test(
      'Days Open uses confirmed service date, not check date, and S/C counts observed services only',
      () async {
    final c = await e.add('Cow');
    await e.birth(c.id, '2026-09-01');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service, day: '2026-09-10', note: 'First');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service, day: '2026-09-20', note: 'Second');
    final s = e.store.byId(c.id)!.modules.dairy!.records.last;
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.pregnancy,
        day: '2026-10-10',
        relatedId: s.id,
        pregnancy: PregnancyResult.positive,
        note: 'Positive only');
    expect(DairyMetrics(e.store.byId(c.id)!, e.now).daysOpen, isNull);
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.pregnancy,
        day: '2026-10-11',
        relatedId: s.id,
        pregnancy: PregnancyResult.positive,
        confirmedConception: true,
        note: 'Confirmed service');
    var m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.daysOpen, 19);
    expect(m.servicesPerConception, 2);
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.pregnancy,
        day: '2026-10-12',
        relatedId: s.id,
        pregnancy: PregnancyResult.negative,
        note: 'Correction');
    m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.daysOpen, isNull);
    expect(m.servicesPerConception, isNull);
  });
  test(
      'Missing cycle or ambiguous multiple confirmed services do not invent fertility metrics',
      () async {
    final c = await e.add('Cow');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service, day: '2026-09-01', note: 'Baseline');
    final s = e.store.byId(c.id)!.modules.dairy!.records.last;
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.pregnancy,
        day: '2026-09-10',
        relatedId: s.id,
        pregnancy: PregnancyResult.positive,
        confirmedConception: true,
        note: 'Confirmed');
    expect(
        DairyMetrics(e.store.byId(c.id)!, e.now).servicesPerConception, isNull);
    await e.birth(c.id, '2026-09-20');
    for (final day in ['2026-10-01', '2026-10-02']) {
      await e.store.recordDairy(c.id,
          kind: DairyRecordKind.service, day: day, note: 'Service');
      final service = e.store.byId(c.id)!.modules.dairy!.records.last;
      await e.store.recordDairy(c.id,
          kind: DairyRecordKind.pregnancy,
          day: '2026-10-20',
          relatedId: service.id,
          pregnancy: PregnancyResult.positive,
          confirmedConception: true,
          note: 'User data');
    }
    expect(DairyMetrics(e.store.byId(c.id)!, e.now).daysOpen, isNull);
  });
  test(
      'Pregnancy uncertain/negative is not calving and cannot confirm conception',
      () async {
    final c = await e.add('Cow');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service, day: '2026-10-01', note: 'IB');
    final service = e.store.byId(c.id)!.modules.dairy!.records.last;
    for (final result in [
      PregnancyResult.negative,
      PregnancyResult.inconclusive
    ]) {
      await e.store.recordDairy(c.id,
          kind: DairyRecordKind.pregnancy,
          day: '2026-10-20',
          relatedId: service.id,
          pregnancy: result,
          note: 'Manual');
      final check = e.store.byId(c.id)!.modules.dairy!.records.last;
      await expectLater(e.birth(c.id, '2026-10-26', relatedId: check.id),
          throwsFormatException);
      await expectLater(
          e.store.recordDairy(c.id,
              kind: DairyRecordKind.pregnancy,
              day: '2026-10-20',
              relatedId: service.id,
              pregnancy: result,
              confirmedConception: true,
              note: 'Bad'),
          throwsFormatException);
    }
    expect(e.store.byId(c.id)!.modules.dairy!.calvings, isEmpty);
  });
  test(
      'Calving fails references/self-link/cycle/used calf without partial cycle publication',
      () async {
    final dam = await e.add('Dam'), calf = await e.add('Calf');
    await e.store.updateReferences(dam.id, TwinReferences(damId: calf.id));
    final before = e.disk;
    for (final id in [dam.id, calf.id, 'missing']) {
      await expectLater(e.birth(dam.id, '2026-10-26', calfId: id),
          throwsA(anyOf(isA<FormatException>(), isA<StateError>())));
      expect(e.disk, before);
      expect(e.store.byId(dam.id)!.modules.dairy, isNull);
    }
  });
  test(
      'Withholding uses explicit inclusive start/exclusive safe-use and union, no automatic treatment duration',
      () async {
    final c = await e.add('Cow');
    for (final day in [
      '2026-10-09',
      '2026-10-10',
      '2026-10-11',
      '2026-10-12'
    ]) {
      await milk(c.id, day, 10);
    }
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.withholding,
        day: '2026-10-10',
        safeUseDay: '2026-10-12',
        note: 'Label pengguna');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.withholding,
        day: '2026-10-11',
        safeUseDay: '2026-10-12',
        note: 'Window overlap');
    var m = DairyMetrics(e.store.byId(c.id)!, e.now);
    expect(m.milk.map((d) => d.withheld), [false, true, true, false]);
    expect(m.milk.fold(0.0, (v, d) => v + d.withheldLiters), 20);
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.udder,
        day: '2026-10-26',
        note: 'Observasi manual');
    expect(DairyMetrics(e.store.byId(c.id)!, e.now).heldToday, isFalse);
  });
  test(
      'Withholding correction preserves previous record and can shorten window explicitly',
      () async {
    final c = await e.add('Cow');
    await milk(c.id, '2026-10-26', 20);
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.withholding,
        day: '2026-10-20',
        safeUseDay: '2026-10-30',
        note: 'Initial');
    final old = e.store.byId(c.id)!.modules.dairy!.records.last;
    expect(e.store.dairyMilk.withheld, 20);
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.withholding,
        day: '2026-10-20',
        safeUseDay: '2026-10-25',
        supersedesId: old.id,
        note: 'Koreksi sesuai sumber');
    expect(e.store.dairyMilk.withheld, 0);
    expect(e.store.dairyMilk.outsideHold, 20);
    expect(e.store.byId(c.id)!.modules.dairy!.records.length, 2);
    await expectLater(
        e.store.recordDairy(c.id,
            kind: DairyRecordKind.withholding,
            day: '2026-10-20',
            safeUseDay: '2026-10-25',
            supersedesId: old.id,
            note: 'Stale correction'),
        throwsFormatException);
  });
  test(
      'Invalid withholding/milk/future dates and absent links fail without writes',
      () async {
    final c = await e.add('Cow');
    final before = e.disk;
    for (final op in [
      () => milk(c.id, '2026-02-31', 12),
      () => milk(c.id, '2026-10-27', 12),
      () => e.store.recordDairy(c.id,
          kind: DairyRecordKind.withholding,
          day: '2026-10-26',
          safeUseDay: '2026-10-26',
          note: 'Bad'),
      () => e.store.recordDairy(c.id,
          kind: DairyRecordKind.phase,
          day: '2026-10-27',
          phase: DairyPhase.fresh,
          note: 'Future'),
      () => e.store.recordDairy(c.id,
          kind: DairyRecordKind.udder,
          day: '2026-10-26',
          healthRecordId: 'missing',
          note: 'Bad')
    ]) {
      await expectLater(op(), throwsFormatException);
      expect(e.disk, before);
    }
  });
  test(
      'Udder observation links actual Shared Health and creates no withholding implicitly',
      () async {
    final c = await e.add('Cow');
    await e.store.recordHealth(c.id,
        kind: HealthKind.treatment,
        occurredAt: e.now,
        note: 'Catatan tindakan');
    final h = e.store.byId(c.id)!.core.health.last;
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.udder,
        day: '2026-10-26',
        healthRecordId: h.id,
        note: 'Observasi');
    expect(e.store.byId(c.id)!.modules.dairy!.holds, isEmpty);
    expect(
        e.store.byId(c.id)!.modules.dairy!.records.last.healthRecordId, h.id);
  });
  test(
      'Herd totals cover active female Dairy only, missing and partial stay explicit',
      () async {
    final a = await e.add('A'),
        b = await e.add('B'),
        missing = await e.add('Missing'),
        male = await e.add('Male', gender: 'Jantan'),
        beef = await e.add('Beef', category: ProductionCategory.beef);
    expect(male.isActive && beef.isActive && missing.isActive, isTrue);
    await milk(a.id, '2026-10-26', 20);
    await e.store.recordMilk(b.id,
        day: '2026-10-26', mode: MilkMode.amPm, am: 8, note: 'AM');
    var h = e.store.dairyMilk;
    expect(h.totalCows, 3);
    expect(h.completeCows, 1);
    expect(h.partialCows, 1);
    expect(h.missingCows, 1);
    expect(h.liters, 28);
    await e.store.setCattleStatus(a.id, CattleStatus.archived);
    h = e.store.dairyMilk;
    expect(h.liters, 8);
    expect(h.totalCows, 2);
    expect(e.store.byId(a.id)!.modules.dairy!.milk.length, 1);
    await expectLater(milk(a.id, '2026-10-25', 10), throwsStateError);
  });
  test('Beef/stock bytes survive Dairy append, calving and backup round trip',
      () async {
    final b = await e.add('Beef', category: ProductionCategory.beef);
    await e.store.recordBeef(b.id,
        kind: BeefRecordKind.purpose,
        purpose: BeefPurpose.fattening,
        note: 'Purpose');
    final before = jsonEncode(TwinCodec.encode(e.store.byId(b.id)!));
    final c = await e.add('Dairy');
    await e.birth(c.id, '2026-10-01');
    await milk(c.id, '2026-10-26', 20);
    await e.store.load();
    expect(jsonEncode(TwinCodec.encode(e.store.byId(b.id)!)), before);
    expect(e.store.feedStock, isEmpty);
  });
  test(
      'Historical Dairy legacy ration remains blocked at save/stock; v2 is tested separately',
      () async {
    final c = await e.add('Cow');
    await e.store.recordWeight(c.id, weightKg: 350, source: 'manual');
    final p = legacyFeedPlan(cattle: e.store.byId(c.id)!, createdAt: e.now);
    await expectLater(e.store.savePlan(p), throwsStateError);
    expect(e.store.beefDemand().total, 0);
    expect(e.store.commandCenter.actions.single.kind,
        FarmActionKind.reviewFeedContext);
  });
  test(
      'Concurrent duplicate milk entries cannot overwrite and stale forms/farm are rejected',
      () async {
    final c = await e.add('Cow');
    final a = milk(c.id, '2026-10-26', 10), b = milk(c.id, '2026-10-26', 20);
    await a;
    await expectLater(b, throwsFormatException);
    expect(e.store.byId(c.id)!.modules.dairy!.milk.length, 1);
    await expectLater(
        e.store.recordMilk(c.id,
            day: '2026-10-25',
            mode: MilkMode.daily,
            total: 10,
            note: 'Stale',
            expectedRevision: 0),
        throwsStateError);
    await expectLater(
        e.store.recordDairy(c.id,
            kind: DairyRecordKind.phase,
            phase: DairyPhase.dry,
            day: '2026-10-26',
            note: 'Other farm',
            expectedFarmId: 'other'),
        throwsStateError);
  });
  test(
      'Disk failure rolls back calving, parity and calf references; retry succeeds once',
      () async {
    final c = await e.add('Dam'), calf = await e.add('Calf');
    final before = e.disk;
    e.fail = true;
    await expectLater(e.birth(c.id, '2026-10-26', parity: 1, calfId: calf.id),
        throwsStateError);
    expect(e.disk, before);
    expect(e.store.byId(c.id)!.modules.dairy, isNull);
    expect(e.store.byId(calf.id)!.core.references.damId, isNull);
    e.fail = false;
    await e.birth(c.id, '2026-10-26', parity: 1, calfId: calf.id);
    expect(e.store.byId(c.id)!.modules.dairy!.calvings.length, 1);
  });
  test(
      'Phase4 Dairy1 migrates once without synthetic records; Beef/stock unchanged',
      () async {
    var disk = migrationFixtures['5-beef']!, writes = 0;
    final old = jsonDecode(disk);
    final s = FarmStore(
        read: () async => disk,
        write: (r) async {
          writes++;
          disk = r;
        });
    addTearDown(s.dispose);
    await s.load();
    expect(s.error, isNull);
    expect(writes, 1);
    final j = jsonDecode(disk);
    expect(j['data']['cattle'][0]['foundation']['modules']['dairy'],
        {'version': 2, 'records': [], 'milk': []});
    expect(j['data']['cattle'][0]['foundation']['modules']['beef'],
        old['data']['cattle'][0]['foundation']['modules']['beef']);
    expect(j['data']['foundation'], old['data']['foundation']);
    await s.load();
    expect(writes, 1);
  });
  test(
      'Failed Dairy1 upgrade preserves disk/state and blocks writes until successful retry',
      () async {
    var disk = migrationFixtures['5-beef']!, fail = true;
    final s = FarmStore(
        read: () async => disk,
        write: (r) async {
          if (fail) throw StateError('disk');
          disk = r;
        });
    addTearDown(s.dispose);
    await s.load();
    expect(s.error, isNotNull);
    expect(s.allCattle, isEmpty);
    expect(disk, migrationFixtures['5-beef']);
    await expectLater(s.settings('No', 'No', 7), throwsStateError);
    fail = false;
    await s.load();
    expect(s.error, isNull);
    expect(
        jsonDecode(disk),
        FarmBackupCodec.encode(
            FarmBackupCodec.decode(migrationFixtures['5-beef']!)));
  });
  for (final issue in [
    'version',
    'milkField',
    'unknownTimezone',
    'idCollision',
    'sessionMix',
    'correction',
    'calvingRef'
  ]) {
    test('Dairy import $issue fails closed and preserves current data',
        () async {
      final c = await e.add('Cow');
      await e.birth(c.id, '2026-10-01');
      await milk(c.id, '2026-10-26', 20);
      final before = e.disk, j = e.store.exportData();
      final d = j['data']['cattle'][0]['foundation']['modules']['dairy'];
      switch (issue) {
        case 'version':
          d['version'] = 999;
        case 'milkField':
          d['milk'][0]['unknown'] = true;
        case 'unknownTimezone':
          d['milk'][0]['recordedAt'] = '2026-10-26T12:00:00';
        case 'idCollision':
          d['milk'][0]['id'] = d['records'][0]['id'];
        case 'sessionMix':
          d['milk'][0]['am'] = 10;
        case 'correction':
          d['milk'][0]['supersedesId'] = 'missing';
        case 'calvingRef':
          d['records'][0]['calfId'] = 'missing';
      }
      await expectLater(
          e.store.restoreBackup(jsonEncode(j)), throwsFormatException);
      expect(e.disk, before);
    });
  }
  test(
      'Future recorded milk is excluded as-of; explicit calendar date is not derived from unknown weight timezone',
      () async {
    final c = await e.add('Cow');
    await milk(c.id, '2026-10-26', 10);
    final j = e.store.exportData(),
        d = j['data']['cattle'][0]['foundation']['modules']['dairy'];
    d['milk'][0]['recordedAt'] = '2026-10-27T12:00:00Z';
    d['milk'][0]['recordedOn'] = '2026-10-27';
    await e.store.restoreBackup(jsonEncode(j));
    expect(DairyMetrics(e.store.byId(c.id)!, e.now).milk, isEmpty);
  });
}
