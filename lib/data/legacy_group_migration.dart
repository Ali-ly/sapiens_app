import '../models/cattle.dart';
import '../models/group_record.dart';
import '../models/legacy_group_membership.dart';
import '../models/livestock_group.dart';
import '../models/persisted_time.dart';

class LegacyGroupMigration {
  static List<LivestockGroup> migrate(List rawGroups,
      List<LegacyGroupMembership> memberships, List<Cattle> cattle,
      [DateTime? migratedAt]) {
    final result = <LivestockGroup>[];
    for (final raw in rawGroups) {
      final json = Map<String, dynamic>.from(raw as Map);
      final id = json['id'] as String;
      final created = PersistedTime.parse(json['createdAt'] as String);
      final archived = json['archivedAt'] == null
          ? null
          : PersistedTime.parse(json['archivedAt'] as String);
      final ids = memberships
          .where((m) => m.groupId == id && m.active)
          .map((m) => m.cattleId)
          .toSet();
      final members = cattle.where((c) => ids.contains(c.id)).toList();
      final average =
          members.isNotEmpty && members.every((c) => c.estimatedWeight != null)
              ? members.fold(0.0, (sum, c) => sum + c.estimatedWeight!) /
                  members.length
              : null;
      // A deterministic reference anchor, not the time migration/observation ran.
      final at = archived ?? created;
      final anchor = (json['archivedAt'] ?? json['createdAt']) as String;
      result.add(LivestockGroup(
          id: id,
          createdAt: created,
          createdAtText: json['createdAt'] as String,
          history: [
            GroupRecord(
                id: 'migration-$id',
                recordedAt: at,
                recordedAtText: anchor,
                archivedAtText: json['archivedAt'] as String?,
                timeBasis: GroupRecordTimeBasis.legacyAnchor,
                name: json['name'] as String,
                headCount: members.length,
                averageWeightKg: average,
                notes: json['notes'] as String? ?? '',
                archivedAt: archived,
                source: 'migration')
          ]));
    }
    // Retain old rows for export, but reject broken old references before migration.
    final groupIds = result.map((g) => g.id).toSet(),
        cattleIds = cattle.map((c) => c.id).toSet();
    final active = <String>{}, rowIds = <String>{};
    for (final m in memberships) {
      if (!groupIds.contains(m.groupId) ||
          !cattleIds.contains(m.cattleId) ||
          !rowIds.add(m.id) ||
          m.active && !active.add(m.cattleId) ||
          m.leftAt != null && m.leftAt!.isBefore(m.joinedAt)) {
        throw const FormatException('Data keanggotaan lama tidak valid.');
      }
    }
    return result;
  }
}
