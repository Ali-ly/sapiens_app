import 'persisted_time.dart';

enum GroupRecordTimeBasis { recorded, legacyAnchor, legacyUnspecified }

/// A full, immutable observation of the bulk herd, including operator changes.
class GroupRecord {
  const GroupRecord(
      {required this.id,
      required this.recordedAt,
      this.recordedAtText,
      this.archivedAtText,
      this.timeBasis = GroupRecordTimeBasis.recorded,
      required this.name,
      required this.headCount,
      this.averageWeightKg,
      this.target = 'pemeliharaan',
      this.notes = '',
      this.archivedAt,
      this.source = 'manual'});
  final String id, name, target, notes, source;
  final DateTime recordedAt;
  final String? recordedAtText, archivedAtText;
  final GroupRecordTimeBasis timeBasis;
  final int headCount;
  final double? averageWeightKg;
  final DateTime? archivedAt;
  bool get archived => archivedAt != null;
  GroupRecord copyWith(
          {required String id,
          required DateTime recordedAt,
          String? name,
          int? headCount,
          double? averageWeightKg,
          bool clearWeight = false,
          String? target,
          String? notes,
          DateTime? archivedAt,
          bool clearArchive = false,
          String? source}) =>
      GroupRecord(
          id: id,
          recordedAt: recordedAt,
          name: name ?? this.name,
          headCount: headCount ?? this.headCount,
          averageWeightKg:
              clearWeight ? null : averageWeightKg ?? this.averageWeightKg,
          target: target ?? this.target,
          notes: notes ?? this.notes,
          archivedAt: clearArchive ? null : archivedAt ?? this.archivedAt,
          source: source ?? this.source,
          archivedAtText:
              clearArchive || archivedAt != null ? null : archivedAtText);
  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': PersistedTime.encode(recordedAt, recordedAtText),
        'name': name,
        'headCount': headCount,
        'averageWeightKg': averageWeightKg,
        'target': target,
        'notes': notes,
        'archivedAt': PersistedTime.optional(archivedAt, archivedAtText),
        'source': source,
        'timeBasis': timeBasis.name
      };
  factory GroupRecord.fromJson(Map<String, dynamic> json) => GroupRecord(
      id: json['id'] as String,
      recordedAt: PersistedTime.parse(json['recordedAt'] as String),
      recordedAtText: json['recordedAt'] as String,
      archivedAtText: json['archivedAt'] as String?,
      timeBasis: json['timeBasis'] == null
          ? (json['source'] == 'migration'
              ? GroupRecordTimeBasis.legacyUnspecified
              : GroupRecordTimeBasis.recorded)
          : GroupRecordTimeBasis.values.byName(json['timeBasis'] as String),
      name: json['name'] as String,
      headCount: json['headCount'] as int,
      averageWeightKg: (json['averageWeightKg'] as num?)?.toDouble(),
      target: json['target'] as String,
      notes: json['notes'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      archivedAt: json['archivedAt'] == null
          ? null
          : PersistedTime.parse(json['archivedAt'] as String));
}
