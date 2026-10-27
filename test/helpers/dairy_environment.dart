import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/state/farm_store.dart';

class DairyEnvironment {
  DairyEnvironment() {
    store = FarmStore(
        read: () async => disk,
        write: (r) async {
          if (fail) throw StateError('disk');
          writes++;
          disk = r;
        },
        now: () => now);
  }
  late FarmStore store;
  String? disk;
  bool fail = false;
  int writes = 0;
  DateTime now = DateTime.utc(2026, 10, 26, 12);
  Future<Cattle> add(String name,
          {String gender = 'Betina',
          ProductionCategory category = ProductionCategory.dairy}) =>
      store.saveCattle(Cattle(
          nameOrId: name,
          gender: gender,
          ageMonths: 18,
          productionCategory: category));
  Future<void> birth(String id, String day,
          {int? parity, String? relatedId, String? calfId}) =>
      store.recordDairy(id,
          kind: DairyRecordKind.calving,
          day: day,
          note: 'Kelahiran aktual pengguna',
          parity: parity,
          relatedId: relatedId,
          calfId: calfId);
}
