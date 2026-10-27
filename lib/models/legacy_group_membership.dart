import 'persisted_time.dart';

/// Read-only compatibility data from schema 3; not operational membership.
class LegacyGroupMembership {
  const LegacyGroupMembership(
      {required this.id,
      required this.cattleId,
      required this.groupId,
      required this.joinedAt,
      this.joinedAtText,
      this.leftAt,
      this.leftAtText});
  final String id, cattleId, groupId;
  final String? joinedAtText, leftAtText;
  final DateTime joinedAt;
  final DateTime? leftAt;
  bool get active => leftAt == null;
  Map<String, dynamic> toJson() => {
        'id': id,
        'cattleId': cattleId,
        'groupId': groupId,
        'joinedAt': PersistedTime.encode(joinedAt, joinedAtText),
        'leftAt': PersistedTime.optional(leftAt, leftAtText)
      };
  factory LegacyGroupMembership.fromJson(Map<String, dynamic> json) =>
      LegacyGroupMembership(
          id: json['id'] as String,
          cattleId: json['cattleId'] as String,
          groupId: json['groupId'] as String,
          joinedAtText: json['joinedAt'] as String,
          joinedAt: PersistedTime.parse(json['joinedAt'] as String),
          leftAtText: json['leftAt'] as String?,
          leftAt: json['leftAt'] == null
              ? null
              : PersistedTime.parse(json['leftAt'] as String));
}
