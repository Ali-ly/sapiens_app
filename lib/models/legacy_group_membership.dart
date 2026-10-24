/// Read-only compatibility data from schema 3; not operational membership.
class LegacyGroupMembership {
  const LegacyGroupMembership(
      {required this.id,
      required this.cattleId,
      required this.groupId,
      required this.joinedAt,
      this.leftAt});
  final String id, cattleId, groupId;
  final DateTime joinedAt;
  final DateTime? leftAt;
  bool get active => leftAt == null;
  Map<String, dynamic> toJson() => {
        'id': id,
        'cattleId': cattleId,
        'groupId': groupId,
        'joinedAt': joinedAt.toIso8601String(),
        'leftAt': leftAt?.toIso8601String()
      };
  factory LegacyGroupMembership.fromJson(Map<String, dynamic> json) =>
      LegacyGroupMembership(
          id: json['id'] as String,
          cattleId: json['cattleId'] as String,
          groupId: json['groupId'] as String,
          joinedAt: DateTime.parse(json['joinedAt'] as String).toUtc(),
          leftAt: json['leftAt'] == null
              ? null
              : DateTime.parse(json['leftAt'] as String).toUtc());
}
