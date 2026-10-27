import '../domain_json.dart';
import '../persisted_time.dart';

enum BeefPurpose { fattening, breeding }

enum BeefPhase { calf, weaned, growing, fattening, finishing, evaluation }

enum BeefRecordKind { purpose, phase, target, service, pregnancy, calving }

enum PregnancyResult { positive, negative, inconclusive }

const beefPurposeLabels = {
  BeefPurpose.fattening: 'Penggemukan',
  BeefPurpose.breeding: 'Pembibitan'
};
const beefPhaseLabels = {
  BeefPhase.calf: 'Anak',
  BeefPhase.weaned: 'Lepas sapih',
  BeefPhase.growing: 'Pertumbuhan',
  BeefPhase.fattening: 'Penggemukan',
  BeefPhase.finishing: 'Finishing',
  BeefPhase.evaluation: 'Siap dievaluasi untuk jual'
};
const beefRecordLabels = {
  BeefRecordKind.purpose: 'Tujuan Beef',
  BeefRecordKind.phase: 'Fase Beef',
  BeefRecordKind.target: 'Target bobot',
  BeefRecordKind.service: 'Breeding / IB',
  BeefRecordKind.pregnancy: 'Pemeriksaan kebuntingan',
  BeefRecordKind.calving: 'Kelahiran'
};
const pregnancyLabels = {
  PregnancyResult.positive: 'Positif (catatan pengguna)',
  PregnancyResult.negative: 'Negatif (catatan pengguna)',
  PregnancyResult.inconclusive: 'Belum pasti'
};

/// Append-only user facts. No inferred phase, pregnancy, or birth date.
class BeefRecord {
  const BeefRecord(
      {required this.id,
      required this.kind,
      required this.recordedAt,
      required this.occurredAt,
      required this.note,
      this.purpose,
      this.phase,
      this.targetKg,
      this.nearKg,
      this.sireId,
      this.relatedId,
      this.calfId,
      this.pregnancy});
  final String id, note;
  final BeefRecordKind kind;
  final DateTime recordedAt, occurredAt;
  final BeefPurpose? purpose;
  final BeefPhase? phase;
  final double? targetKg, nearKg;
  final String? sireId, relatedId, calfId;
  final PregnancyResult? pregnancy;
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'note': note,
        if (purpose != null) 'purpose': purpose!.name,
        if (phase != null) 'phase': phase!.name,
        if (targetKg != null) 'targetKg': targetKg,
        if (nearKg != null) 'nearKg': nearKg,
        if (sireId != null) 'sireId': sireId,
        if (relatedId != null) 'relatedId': relatedId,
        if (calfId != null) 'calfId': calfId,
        if (pregnancy != null) 'pregnancy': pregnancy!.name
      };
  factory BeefRecord.fromJson(Map<String, dynamic> j) {
    final kind = BeefRecordKind.values.byName(j['kind'] as String);
    DomainJson.fields(j, {
      'id',
      'kind',
      'recordedAt',
      'occurredAt',
      'note',
      ...switch (kind) {
        BeefRecordKind.purpose => {'purpose'},
        BeefRecordKind.phase => {'phase'},
        BeefRecordKind.target => {'targetKg', 'nearKg'},
        BeefRecordKind.service => {'sireId'},
        BeefRecordKind.pregnancy => {'relatedId', 'pregnancy'},
        BeefRecordKind.calving => {'relatedId', 'calfId'}
      }
    });
    for (final key in ['recordedAt', 'occurredAt']) {
      if (PersistedTime.basis(j[key] as String) !=
          TimestampBasis.explicitOffset) {
        throw const FormatException(
            'Waktu catatan Beef harus memiliki zona waktu.');
      }
    }
    return BeefRecord(
        id: j['id'] as String,
        kind: kind,
        recordedAt: PersistedTime.parse(j['recordedAt'] as String),
        occurredAt: PersistedTime.parse(j['occurredAt'] as String),
        note: j['note'] as String,
        purpose: j['purpose'] == null
            ? null
            : BeefPurpose.values.byName(j['purpose'] as String),
        phase: j['phase'] == null
            ? null
            : BeefPhase.values.byName(j['phase'] as String),
        targetKg: (j['targetKg'] as num?)?.toDouble(),
        nearKg: (j['nearKg'] as num?)?.toDouble(),
        sireId: j['sireId'] as String?,
        relatedId: j['relatedId'] as String?,
        calfId: j['calfId'] as String?,
        pregnancy: j['pregnancy'] == null
            ? null
            : PregnancyResult.values.byName(j['pregnancy'] as String));
  }
}
