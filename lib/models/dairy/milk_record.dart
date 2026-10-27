import '../domain_json.dart';
import '../persisted_time.dart';

enum MilkMode { daily, amPm }

const milkModeLabels = {
  MilkMode.daily: 'Total harian',
  MilkMode.amPm: 'AM + PM'
};

/// One immutable whole-day snapshot. A correction must supersede the latest
/// snapshot for the same civil date; never add daily total to its sessions.
class MilkRecord {
  const MilkRecord(
      {required this.id,
      required this.recordedAt,
      required this.recordedOn,
      required this.day,
      required this.mode,
      required this.note,
      this.total,
      this.am,
      this.pm,
      this.supersedesId,
      this.qualityNote = ''});
  final String id, recordedOn, day, note, qualityNote;
  final DateTime recordedAt;
  final MilkMode mode;
  final double? total, am, pm;
  final String? supersedesId;
  bool get complete =>
      mode == MilkMode.daily ? total != null : am != null && pm != null;
  double get recordedLiters =>
      mode == MilkMode.daily ? total ?? 0 : (am ?? 0) + (pm ?? 0);
  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'recordedOn': recordedOn,
        'day': day,
        'mode': mode.name,
        'note': note,
        'qualityNote': qualityNote,
        if (total != null) 'total': total,
        if (am != null) 'am': am,
        if (pm != null) 'pm': pm,
        if (supersedesId != null) 'supersedesId': supersedesId
      };
  factory MilkRecord.fromJson(Map<String, dynamic> j) {
    DomainJson.fields(j, {
      'id',
      'recordedAt',
      'recordedOn',
      'day',
      'mode',
      'note',
      'qualityNote',
      'total',
      'am',
      'pm',
      'supersedesId'
    });
    if (PersistedTime.basis(j['recordedAt'] as String) !=
        TimestampBasis.explicitOffset) {
      throw const FormatException('Zona waktu pencatatan susu wajib tersedia.');
    }
    return MilkRecord(
        id: j['id'] as String,
        recordedAt: PersistedTime.parse(j['recordedAt'] as String),
        recordedOn: j['recordedOn'] as String,
        day: j['day'] as String,
        mode: MilkMode.values.byName(j['mode'] as String),
        note: j['note'] as String,
        qualityNote: j['qualityNote'] as String? ?? '',
        total: (j['total'] as num?)?.toDouble(),
        am: (j['am'] as num?)?.toDouble(),
        pm: (j['pm'] as num?)?.toDouble(),
        supersedesId: j['supersedesId'] as String?);
  }
}
