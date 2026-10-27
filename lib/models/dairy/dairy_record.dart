import '../beef/beef_record.dart' show PregnancyResult;
import '../domain_json.dart';
import '../persisted_time.dart';
export '../beef/beef_record.dart' show PregnancyResult;

enum DairyPhase {
  newborn,
  preWeaning,
  weaned,
  heifer,
  breedingReady,
  firstPregnancy,
  closeUp,
  calving,
  fresh,
  early,
  mid,
  late,
  dry
}

enum DairyRecordKind { phase, service, pregnancy, calving, udder, withholding }

const dairyPhaseLabels = {
  DairyPhase.newborn: 'Pedet baru lahir',
  DairyPhase.preWeaning: 'Pre-Weaning',
  DairyPhase.weaned: 'Lepas sapih',
  DairyPhase.heifer: 'Dara / Heifer',
  DairyPhase.breedingReady: 'Dara siap breeding',
  DairyPhase.firstPregnancy: 'Bunting pertama',
  DairyPhase.closeUp: 'Close-Up',
  DairyPhase.calving: 'Calving',
  DairyPhase.fresh: 'Fresh Cow',
  DairyPhase.early: 'Early Lactation',
  DairyPhase.mid: 'Mid Lactation',
  DairyPhase.late: 'Late Lactation',
  DairyPhase.dry: 'Dry Period'
};
const dairyRecordLabels = {
  DairyRecordKind.phase: 'Fase Dairy',
  DairyRecordKind.service: 'Breeding / IB',
  DairyRecordKind.pregnancy: 'Pemeriksaan kebuntingan',
  DairyRecordKind.calving: 'Calving / siklus baru',
  DairyRecordKind.udder: 'Observasi ambing / susu',
  DairyRecordKind.withholding: 'Masa tahan susu'
};

class DairyRecord {
  const DairyRecord(
      {required this.id,
      required this.kind,
      required this.recordedAt,
      required this.recordedOn,
      required this.day,
      required this.note,
      this.phase,
      this.sireId,
      this.relatedId,
      this.calfId,
      this.pregnancy,
      this.confirmedConception = false,
      this.parity,
      this.safeUseDay,
      this.supersedesId,
      this.healthRecordId});
  final String id, recordedOn, day, note;
  final DairyRecordKind kind;
  final DateTime recordedAt;
  final DairyPhase? phase;
  final String? sireId,
      relatedId,
      calfId,
      safeUseDay,
      supersedesId,
      healthRecordId;
  final PregnancyResult? pregnancy;
  final bool confirmedConception;
  final int? parity;
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'recordedOn': recordedOn,
        'day': day,
        'note': note,
        if (phase != null) 'phase': phase!.name,
        if (sireId != null) 'sireId': sireId,
        if (relatedId != null) 'relatedId': relatedId,
        if (calfId != null) 'calfId': calfId,
        if (pregnancy != null) 'pregnancy': pregnancy!.name,
        if (kind == DairyRecordKind.pregnancy)
          'confirmedConception': confirmedConception,
        if (parity != null) 'parity': parity,
        if (safeUseDay != null) 'safeUseDay': safeUseDay,
        if (supersedesId != null) 'supersedesId': supersedesId,
        if (healthRecordId != null) 'healthRecordId': healthRecordId
      };
  factory DairyRecord.fromJson(Map<String, dynamic> j) {
    final k = DairyRecordKind.values.byName(j['kind'] as String);
    DomainJson.fields(j, {
      'id',
      'kind',
      'recordedAt',
      'recordedOn',
      'day',
      'note',
      ...switch (k) {
        DairyRecordKind.phase => {'phase'},
        DairyRecordKind.service => {'sireId'},
        DairyRecordKind.pregnancy => {
            'relatedId',
            'pregnancy',
            'confirmedConception'
          },
        DairyRecordKind.calving => {'relatedId', 'calfId', 'parity'},
        DairyRecordKind.udder => {'healthRecordId'},
        DairyRecordKind.withholding => {'safeUseDay', 'supersedesId'}
      }
    });
    if (PersistedTime.basis(j['recordedAt'] as String) !=
        TimestampBasis.explicitOffset) {
      throw const FormatException(
          'Zona waktu pencatatan Dairy wajib tersedia.');
    }
    return DairyRecord(
        id: j['id'] as String,
        kind: k,
        recordedAt: PersistedTime.parse(j['recordedAt'] as String),
        recordedOn: j['recordedOn'] as String,
        day: j['day'] as String,
        note: j['note'] as String,
        phase: j['phase'] == null
            ? null
            : DairyPhase.values.byName(j['phase'] as String),
        sireId: j['sireId'] as String?,
        relatedId: j['relatedId'] as String?,
        calfId: j['calfId'] as String?,
        pregnancy: j['pregnancy'] == null
            ? null
            : PregnancyResult.values.byName(j['pregnancy'] as String),
        confirmedConception: j['confirmedConception'] as bool? ?? false,
        parity: j['parity'] as int?,
        safeUseDay: j['safeUseDay'] as String?,
        supersedesId: j['supersedesId'] as String?,
        healthRecordId: j['healthRecordId'] as String?);
  }
}
