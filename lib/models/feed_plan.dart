import 'beef/beef_feed_context.dart';
import 'cattle.dart';
import 'feed_api_v2.dart';
import 'feed_nutrition_snapshot.dart';
import 'persisted_time.dart';

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

enum FeedPlanType { legacyRation, nutritionEvaluation }

class FeedPlan {
  FeedPlan(
      {required this.id,
      this.beefContext,
      this.nutritionSnapshot,
      this.nutritionRequest,
      this.type = FeedPlanType.legacyRation,
      required this.cattleId,
      required this.cattleName,
      required this.weightKg,
      required this.ageMonths,
      required this.gender,
      required this.bodyCondition,
      required this.target,
      required List<String> availableFeeds,
      required this.createdAt,
      this.createdAtText,
      required List<FeedPortion> portions,
      this.weightDate,
      this.weightDateText,
      this.totalDryMatterKg,
      this.warning,
      List<String> notes = const []})
      : availableFeeds = List.unmodifiable(availableFeeds),
        portions = List.unmodifiable(portions),
        notes = List.unmodifiable(notes);
  factory FeedPlan.nutrition(
      {required String id,
      required Cattle cattle,
      required NutritionRequest request,
      required NutritionResponse response,
      required DateTime createdAt}) {
    if (cattle.estimatedWeight == null) {
      throw const FormatException('Bobot sapi belum tersedia untuk snapshot.');
    }
    return FeedPlan(
      id: id,
      type: FeedPlanType.nutritionEvaluation,
      cattleId: cattle.id,
      cattleName: cattle.nameOrId,
      weightKg: cattle.estimatedWeight!,
      ageMonths: cattle.ageMonths,
      gender: cattle.gender,
      bodyCondition: null,
      target: null,
      availableFeeds: request.feedItems.map((f) => f.feedId).toList(),
      portions: request.feedItems
          .map((f) => FeedPortion(key: f.feedId, asFedKg: f.asFedKgDay))
          .toList(),
      createdAt: createdAt,
      weightDate: cattle.history.isEmpty ? null : cattle.history.last.date,
      weightDateText:
          cattle.history.isEmpty ? null : cattle.history.last.dateText,
      nutritionRequest: request,
      nutritionSnapshot: FeedNutritionSnapshot(
          productionCategory: request.productionCategory, response: response),
    );
  }

  /// Original v2 input, kept independently of the immutable backend response.
  /// The explicit type distinguishes it from a legacy ration snapshot.
  final NutritionRequest? nutritionRequest;
  final FeedPlanType type;
  bool get isNutritionEvaluation => type == FeedPlanType.nutritionEvaluation;
  final BeefFeedContext? beefContext;
  final FeedNutritionSnapshot? nutritionSnapshot;

  /// No inference from old Beef context, cattle identity, or target labels.
  ProductionCategory? get productionCategory =>
      nutritionSnapshot?.productionCategory;
  final String id, cattleId, cattleName, gender;
  final String? bodyCondition, target;
  final double weightKg;
  final int ageMonths;
  final List<String> availableFeeds, notes;
  final String? createdAtText, weightDateText;
  final DateTime createdAt;
  final DateTime? weightDate;
  final List<FeedPortion> portions;
  final double? totalDryMatterKg;
  final String? warning;
  double get totalFreshKg => portions.fold(0.0, (sum, p) => sum + p.asFedKg);
  bool matches(Cattle c) =>
      c.id == cattleId &&
      (productionCategory == null ||
          productionCategory == c.productionCategory) &&
      (beefContext == null || beefContext!.matches(c)) &&
      c.estimatedWeight == weightKg &&
      c.ageMonths == ageMonths &&
      c.gender == gender &&
      (c.history.isEmpty
          ? weightDate == null
          : weightDate != null &&
              c.history.last.date.isAtSameMomentAs(weightDate!));

  Map<String, dynamic> toJson() => {
        'id': id,
        if (isNutritionEvaluation) 'planType': type.name,
        if (nutritionRequest != null)
          'nutritionRequest': nutritionRequest!.toJson(),
        if (nutritionSnapshot != null)
          'nutritionSnapshot': nutritionSnapshot!.toJson(),
        if (beefContext != null) 'beefContext': beefContext!.toJson(),
        'cattleId': cattleId,
        'cattleName': cattleName,
        'weightKg': weightKg,
        'ageMonths': ageMonths,
        'gender': gender,
        'bodyCondition': bodyCondition,
        'target': target,
        'availableFeeds': availableFeeds,
        'createdAt': PersistedTime.encode(createdAt, createdAtText),
        'weightDate': PersistedTime.optional(weightDate, weightDateText),
        'portions': portions.map((p) => p.toJson()).toList(),
        'totalDryMatterKg': totalDryMatterKg,
        'warning': warning,
        'notes': notes
      };
  factory FeedPlan.fromJson(Map<String, dynamic> json) => FeedPlan(
        id: json['id'] as String,
        type: switch (json['planType']) {
          null || 'legacyRation' => FeedPlanType.legacyRation,
          'nutritionEvaluation' => FeedPlanType.nutritionEvaluation,
          _ => throw const FormatException('Tipe rencana pakan belum didukung.')
        },
        nutritionRequest: json['nutritionRequest'] == null
            ? null
            : NutritionRequest.fromJson(
                Map<String, dynamic>.from(json['nutritionRequest'] as Map)),
        nutritionSnapshot: json['nutritionSnapshot'] == null
            ? null
            : FeedNutritionSnapshot.fromJson(
                Map<String, dynamic>.from(json['nutritionSnapshot'] as Map)),
        beefContext: json['beefContext'] == null
            ? null
            : BeefFeedContext.fromJson(
                Map<String, dynamic>.from(json['beefContext'] as Map)),
        cattleId: json['cattleId'] as String,
        cattleName: json['cattleName'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        ageMonths: json['ageMonths'] as int,
        gender: json['gender'] as String,
        bodyCondition: json['bodyCondition'] as String?,
        target: json['target'] as String?,
        availableFeeds: List<String>.from(json['availableFeeds'] as List),
        createdAtText: json['createdAt'] as String,
        createdAt: PersistedTime.parse(json['createdAt'] as String),
        weightDateText: json['weightDate'] as String?,
        weightDate: json['weightDate'] == null
            ? null
            : PersistedTime.parse(json['weightDate'] as String),
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
