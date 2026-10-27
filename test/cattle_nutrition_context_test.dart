import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/services/cattle_nutrition_context.dart';

import 'helpers/beef_environment.dart';
import 'helpers/dairy_environment.dart';

void main() {
  test('Beef purpose comes from Twin, weight target is not invented ADG',
      () async {
    final e = BeefEnvironment();
    await e.store.load();
    final c = await e.add('Beef');
    await e.setup(c.id);
    await e.store.recordWeight(c.id, weightKg: 300, source: 'manual');
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.target, targetKg: 450, note: 'Weight target');
    expect(CattleNutritionContext.fromTwin(e.store.byId(c.id)!, e.now).toJson(),
        {'body_weight_kg': 300, 'purpose': 'penggemukan'});
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.purpose,
        purpose: BeefPurpose.breeding,
        note: 'Explicit change');
    expect(CattleNutritionContext.fromTwin(e.store.byId(c.id)!, e.now).toJson(),
        {'body_weight_kg': 300, 'purpose': 'pembibitan'});
  });
  const stageMapping = {
    DairyPhase.preWeaning: 'preweaning_calf',
    DairyPhase.heifer: 'growing_heifer',
    DairyPhase.firstPregnancy: 'pregnant_heifer',
    DairyPhase.fresh: 'fresh',
    DairyPhase.early: 'early_lactation',
    DairyPhase.mid: 'mid_lactation',
    DairyPhase.late: 'late_lactation',
    DairyPhase.dry: 'dry_far_off',
    DairyPhase.closeUp: 'close_up',
  };
  for (final entry in stageMapping.entries) {
    test('Dairy ${entry.key.name} maps explicitly to ${entry.value}', () async {
      final e = DairyEnvironment();
      await e.store.load();
      final c = await e.add('Dairy');
      await e.store.recordWeight(c.id, weightKg: 450, source: 'manual');
      await e.store.recordDairy(c.id,
          kind: DairyRecordKind.phase,
          day: '2026-10-26',
          phase: entry.key,
          note: 'Manual phase');
      await e.store.recordMilk(c.id,
          day: '2026-10-26',
          mode: MilkMode.amPm,
          am: 5,
          note: 'Partial liters');
      expect(
          CattleNutritionContext.fromTwin(e.store.byId(c.id)!, e.now).toJson(),
          {'body_weight_kg': 450, 'dairy_stage': entry.value});
    });
  }
  for (final stage in [
    DairyPhase.newborn,
    DairyPhase.weaned,
    DairyPhase.breedingReady,
    DairyPhase.calving
  ]) {
    test('Unmapped ${stage.name} blocks instead of inferring another phase',
        () async {
      final e = DairyEnvironment();
      await e.store.load();
      final c = await e.add('Dairy');
      await e.store.recordWeight(c.id, weightKg: 450, source: 'manual');
      await e.store.recordDairy(c.id,
          kind: DairyRecordKind.phase,
          day: '2026-10-26',
          phase: stage,
          note: 'Manual phase');
      expect(
          () => CattleNutritionContext.fromTwin(e.store.byId(c.id)!, e.now),
          throwsA(isA<FormatException>().having((e) => e.message, 'message',
              contains('belum memiliki padanan'))));
    });
  }
  for (final parity in [1, 2, null]) {
    test('Recorded parity $parity produces only the confirmed backend group',
        () async {
      final e = DairyEnvironment();
      await e.store.load();
      final c = await e.add('Dairy');
      await e.store.recordWeight(c.id, weightKg: 450, source: 'manual');
      await e.birth(c.id, '2026-10-26', parity: parity);
      await e.store.recordDairy(c.id,
          kind: DairyRecordKind.phase,
          day: '2026-10-26',
          phase: DairyPhase.fresh,
          note: 'Manual phase');
      final j =
          CattleNutritionContext.fromTwin(e.store.byId(c.id)!, e.now).toJson();
      expect(j['dim'], 0);
      if (parity == null) {
        expect(j.containsKey('parity_group'), isFalse);
      } else {
        expect(j['parity_group'], parity == 1 ? 'primiparous' : 'multiparous');
      }
      expect(j.containsKey('milk_kg_day'), isFalse);
    });
  }
  test('Multiple recorded cycles are not treated as a known parity number',
      () async {
    final e = DairyEnvironment();
    await e.store.load();
    final c = await e.add('Dairy');
    await e.store.recordWeight(c.id, weightKg: 450, source: 'manual');
    await e.birth(c.id, '2025-10-26');
    await e.birth(c.id, '2026-10-26');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.phase,
        day: '2026-10-26',
        phase: DairyPhase.fresh,
        note: 'Manual phase');
    expect(
        CattleNutritionContext.fromTwin(e.store.byId(c.id)!, e.now)
            .toJson()
            .containsKey('parity_group'),
        isFalse);
  });
  test('Ordinary heifer mapping rejects male or already-calved context',
      () async {
    final e = DairyEnvironment();
    await e.store.load();
    final c = await e.add('Dairy');
    await e.store.recordWeight(c.id, weightKg: 450, source: 'manual');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.phase,
        day: '2026-10-26',
        phase: DairyPhase.heifer,
        note: 'Manual phase');
    expect(
        () => CattleNutritionContext.fromTwin(
            e.store.byId(c.id)!.copyWith(gender: 'Jantan'), e.now),
        throwsFormatException);
    await e.birth(c.id, '2026-10-26', parity: 1);
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.phase,
        day: '2026-10-26',
        phase: DairyPhase.heifer,
        note: 'Conflicting phase');
    expect(() => CattleNutritionContext.fromTwin(e.store.byId(c.id)!, e.now),
        throwsFormatException);
  });
  test(
      'DIM and parity group use actual calving baseline; milk liters are not kg',
      () async {
    final e = DairyEnvironment();
    await e.store.load();
    final c = await e.add('Dairy');
    await e.store.recordWeight(c.id, weightKg: 450, source: 'manual');
    await e.birth(c.id, '2026-10-01', parity: 3);
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.phase,
        day: '2026-10-26',
        phase: DairyPhase.fresh,
        note: 'Manual phase');
    await e.store.recordMilk(c.id,
        day: '2026-10-26',
        mode: MilkMode.daily,
        total: 12,
        note: 'Complete liters');
    expect(
        CattleNutritionContext.fromTwin(e.store.byId(c.id)!, e.now).toJson(), {
      'body_weight_kg': 450,
      'dairy_stage': 'fresh',
      'dim': 25,
      'parity_group': 'multiparous'
    });
  });
  test(
      'Missing category, purpose, Dairy phase, weight and inactive status fail explicitly',
      () {
    final c = Cattle(
        nameOrId: 'Legacy',
        gender: 'Jantan',
        ageMonths: 18,
        estimatedWeight: 300);
    for (final invalid in [
      c,
      c.copyWith(productionCategory: ProductionCategory.beef),
      c.copyWith(productionCategory: ProductionCategory.dairy),
      Cattle(
          nameOrId: 'No weight',
          gender: 'Betina',
          ageMonths: 18,
          productionCategory: ProductionCategory.dairy)
    ]) {
      expect(
          () => CattleNutritionContext.fromTwin(
              invalid, DateTime.utc(2026, 10, 26)),
          throwsFormatException);
    }
  });
}
