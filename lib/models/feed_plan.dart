import 'cattle.dart';

const feedLabels = {
  'rumput': 'Rumput hijauan',
  'jerami': 'Jerami padi',
  'dedak': 'Dedak padi'
};
const targetLabels = {
  'pemeliharaan': 'Pemeliharaan',
  'pertumbuhan': 'Pertumbuhan',
  'penggemukan': 'Penggemukan'
};

class FeedPortion {
  const FeedPortion(
      {required this.key, required this.asFedKg, this.dryMatterKg, this.ratio});
  final String key;
  final double asFedKg;
  final double? dryMatterKg, ratio;
  String get label => feedLabels[key] ?? key;
  Map<String, dynamic> toJson() => {
        'key': key,
        'asFedKg': asFedKg,
        'dryMatterKg': dryMatterKg,
        'ratio': ratio
      };
  factory FeedPortion.fromJson(Map<String, dynamic> json) => FeedPortion(
        key: json['key'] as String,
        asFedKg: (json['asFedKg'] as num).toDouble(),
        dryMatterKg: (json['dryMatterKg'] as num?)?.toDouble(),
        ratio: (json['ratio'] as num?)?.toDouble(),
      );
}

class FeedPlan {
  FeedPlan(
      {required this.id,
      required this.cattleId,
      required this.cattleName,
      required this.weightKg,
      required this.ageMonths,
      required this.gender,
      required this.bodyCondition,
      required this.target,
      required List<String> availableFeeds,
      required this.createdAt,
      required List<FeedPortion> portions,
      this.weightDate,
      this.totalDryMatterKg,
      this.warning,
      List<String> notes = const []})
      : availableFeeds = List.unmodifiable(availableFeeds),
        portions = List.unmodifiable(portions),
        notes = List.unmodifiable(notes);
  final String id, cattleId, cattleName, gender, bodyCondition, target;
  final double weightKg;
  final int ageMonths;
  final List<String> availableFeeds, notes;
  final DateTime createdAt;
  final DateTime? weightDate;
  final List<FeedPortion> portions;
  final double? totalDryMatterKg;
  final String? warning;
  double get totalFreshKg => portions.fold(0.0, (sum, p) => sum + p.asFedKg);
  bool matches(Cattle c) =>
      c.id == cattleId &&
      c.estimatedWeight == weightKg &&
      c.ageMonths == ageMonths &&
      c.gender == gender &&
      (c.history.isEmpty ? null : c.history.last.date) == weightDate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'cattleId': cattleId,
        'cattleName': cattleName,
        'weightKg': weightKg,
        'ageMonths': ageMonths,
        'gender': gender,
        'bodyCondition': bodyCondition,
        'target': target,
        'availableFeeds': availableFeeds,
        'createdAt': createdAt.toIso8601String(),
        'weightDate': weightDate?.toIso8601String(),
        'portions': portions.map((p) => p.toJson()).toList(),
        'totalDryMatterKg': totalDryMatterKg,
        'warning': warning,
        'notes': notes
      };
  factory FeedPlan.fromJson(Map<String, dynamic> json) => FeedPlan(
        id: json['id'] as String,
        cattleId: json['cattleId'] as String,
        cattleName: json['cattleName'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        ageMonths: json['ageMonths'] as int,
        gender: json['gender'] as String,
        bodyCondition: json['bodyCondition'] as String,
        target: json['target'] as String,
        availableFeeds: List<String>.from(json['availableFeeds'] as List),
        createdAt: DateTime.parse(json['createdAt'] as String),
        weightDate: json['weightDate'] == null
            ? null
            : DateTime.parse(json['weightDate'] as String),
        portions: (json['portions'] as List)
            .map(
              (p) => FeedPortion.fromJson(Map<String, dynamic>.from(p as Map)),
            )
            .toList(),
        totalDryMatterKg: (json['totalDryMatterKg'] as num?)?.toDouble(),
        warning: json['warning'] as String?,
        notes: List<String>.from(json['notes'] as List? ?? []),
      );
}
