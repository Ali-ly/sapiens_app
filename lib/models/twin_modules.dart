import 'beef/beef_record.dart';
import 'dairy/dairy_record.dart';
import 'dairy/milk_record.dart';

export 'beef/beef_record.dart';
export 'dairy/dairy_record.dart';
export 'dairy/milk_record.dart';

/// Versioned domain history survives production-category changes.
class BeefExtension {
  const BeefExtension() : records = const [];
  BeefExtension.withRecords(List<BeefRecord> records)
      : records = List.unmodifiable(records);
  final List<BeefRecord> records;
  BeefRecord? latest(BeefRecordKind kind) {
    for (final record in records.reversed) {
      if (record.kind == kind) return record;
    }
    return null;
  }

  BeefPurpose? get purpose => latest(BeefRecordKind.purpose)?.purpose;
  BeefPhase? get phase => latest(BeefRecordKind.phase)?.phase;
  Map<String, dynamic> toJson() =>
      {'version': 2, 'records': records.map((r) => r.toJson()).toList()};
}

class DairyExtension {
  const DairyExtension()
      : records = const [],
        milk = const [];
  DairyExtension.withRecords(
      {List<DairyRecord> records = const [], List<MilkRecord> milk = const []})
      : records = List.unmodifiable(records),
        milk = List.unmodifiable(milk);
  final List<DairyRecord> records;
  final List<MilkRecord> milk;
  int get revision => records.length + milk.length;
  DairyPhase? get phase {
    for (final r in records.reversed) {
      if (r.kind == DairyRecordKind.phase) return r.phase;
      if (r.kind == DairyRecordKind.calving) return DairyPhase.calving;
    }
    return null;
  }

  Map<String, MilkRecord> get milkDays =>
      Map.unmodifiable({for (final m in milk) m.day: m});
  List<DairyRecord> get calvings => List.unmodifiable(
      records.where((r) => r.kind == DairyRecordKind.calving));
  List<DairyRecord> get holds {
    final active = <String, DairyRecord>{};
    for (final r
        in records.where((r) => r.kind == DairyRecordKind.withholding)) {
      active.remove(r.supersedesId);
      active[r.id] = r;
    }
    return List.unmodifiable(active.values);
  }

  Map<String, dynamic> toJson() => {
        'version': 2,
        'records': records.map((r) => r.toJson()).toList(),
        'milk': milk.map((r) => r.toJson()).toList()
      };
}

class TwinModules {
  const TwinModules({this.beef, this.dairy});
  final BeefExtension? beef;
  final DairyExtension? dairy;
}
