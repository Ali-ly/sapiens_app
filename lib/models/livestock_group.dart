import 'group_record.dart';

/// A bulk herd independent of individual cattle. Current data is the latest record.
class LivestockGroup {
  LivestockGroup(
      {required this.id,
      required this.createdAt,
      required List<GroupRecord> history})
      : history = List.unmodifiable(history) {
    if (history.isEmpty) {
      throw const FormatException('Riwayat data kelompok tidak boleh kosong.');
    }
  }
  final String id;
  final DateTime createdAt;
  final List<GroupRecord> history;
  GroupRecord get current => history.last;
  String get name => current.name;
  String get notes => current.notes;
  int get headCount => current.headCount;
  double? get averageWeightKg => current.averageWeightKg;
  String get target => current.target;
  DateTime? get archivedAt => current.archivedAt;
  bool get archived => current.archived;
  bool get canCalculateFeed =>
      !archived && headCount > 0 && averageWeightKg != null;

  /// Only quantitative changes invalidate a feed estimate; renaming does not.
  String get inputRevision {
    var record = history.first;
    for (final next in history.skip(1)) {
      if (next.headCount != record.headCount ||
          next.averageWeightKg != record.averageWeightKg ||
          next.target != record.target) {
        record = next;
      }
    }
    return record.id;
  }

  LivestockGroup append(GroupRecord record) => LivestockGroup(
      id: id, createdAt: createdAt, history: [...history, record]);
  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'history': history.map((r) => r.toJson()).toList()
      };
  factory LivestockGroup.fromJson(Map<String, dynamic> json) => LivestockGroup(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      history: (json['history'] as List)
          .map((value) =>
              GroupRecord.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList());
}
