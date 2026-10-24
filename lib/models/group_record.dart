/// A full, immutable observation of the bulk herd, including operator changes.
class GroupRecord {
  const GroupRecord(
      {required this.id,
      required this.recordedAt,
      required this.name,
      required this.headCount,
      this.averageWeightKg,
      this.target = 'pemeliharaan',
      this.notes = '',
      this.archivedAt,
      this.source = 'manual'});
  final String id, name, target, notes, source;
  final DateTime recordedAt;
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
          source: source ?? this.source);
  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toIso8601String(),
        'name': name,
        'headCount': headCount,
        'averageWeightKg': averageWeightKg,
        'target': target,
        'notes': notes,
        'archivedAt': archivedAt?.toIso8601String(),
        'source': source
      };
  factory GroupRecord.fromJson(Map<String, dynamic> json) => GroupRecord(
      id: json['id'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String).toUtc(),
      name: json['name'] as String,
      headCount: json['headCount'] as int,
      averageWeightKg: (json['averageWeightKg'] as num?)?.toDouble(),
      target: json['target'] as String,
      notes: json['notes'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String).toUtc());
}
