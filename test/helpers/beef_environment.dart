import 'package:sapita_app/models/beef/beef_feed_context.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_plan.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'legacy_feed_plan_fixture.dart';

class BeefEnvironment {
  BeefEnvironment() {
    store = FarmStore(
        read: () async => disk,
        write: (r) async {
          if (fail) throw StateError('disk');
          disk = r;
        },
        now: () => now);
  }
  late FarmStore store;
  String? disk;
  bool fail = false;
  DateTime now = DateTime.utc(2026, 10, 26, 10);
  Future<Cattle> add(String name,
          {String gender = 'Jantan',
          ProductionCategory category = ProductionCategory.beef}) =>
      store.saveCattle(Cattle(
          id: '',
          nameOrId: name,
          gender: gender,
          ageMonths: 18,
          productionCategory: category));
  Future<void> setup(String id,
      {BeefPurpose purpose = BeefPurpose.fattening,
      BeefPhase phase = BeefPhase.fattening}) async {
    await store.recordBeef(id,
        kind: BeefRecordKind.purpose,
        purpose: purpose,
        note: 'Pilihan pengguna');
    await store.recordBeef(id,
        kind: BeefRecordKind.phase, phase: phase, note: 'Observasi manual');
  }

  Future<FeedPlan> plan(String id) async {
    await store.recordWeight(id, weightKg: 350, source: 'manual');
    final context = store.byId(id)!.modules.beef!;
    final p = legacyFeedPlan(
        cattle: store.byId(id)!,
        createdAt: now,
        beefContext: BeefFeedContext(
            revision: context.records.length,
            purpose: context.purpose!,
            phase: context.phase!));
    return p;
  }
}
