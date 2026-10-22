import 'cattle_draft.dart';

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
  factory FeedPortion.fromJson(Map<String, dynamic> j) => FeedPortion(
      key: j['key'] as String,
      asFedKg: (j['asFedKg'] as num).toDouble(),
      dryMatterKg: (j['dryMatterKg'] as num?)?.toDouble(),
      ratio: (j['ratio'] as num?)?.toDouble());
}

class FeedPlan {
  static int _idCounter = 0;
  const FeedPlan(
      {required this.id,
      required this.cattleId,
      required this.cattleName,
      required this.weightKg,
      required this.ageMonths,
      required this.gender,
      required this.bodyCondition,
      required this.target,
      required this.availableFeeds,
      required this.createdAt,
      required this.portions,
      this.weightDate,
      this.totalDryMatterKg,
      this.warning,
      this.notes = const []});
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
  bool matches(CattleDraft c) =>
      c.id == cattleId &&
      c.estimatedWeight == weightKg &&
      c.ageMonths == ageMonths &&
      c.gender == gender &&
      (c.history.isEmpty ? null : c.history.last.date) == weightDate;

  static double? _optionalNumber(dynamic value) {
    if (value == null) return null;
    if (value is! num || !value.isFinite)
      throw const FormatException('Angka dari layanan pakan tidak valid.');
    return value.toDouble();
  }

  factory FeedPlan.fromApi(
      {required CattleDraft cattle,
      required String target,
      required String condition,
      required List<String> feeds,
      required Map<String, dynamic> data}) {
    final raw = data['recommendation'];
    if (raw is! Map || raw.isEmpty)
      throw const FormatException(
          'Layanan pakan belum mengembalikan takaran yang dapat digunakan.');
    final portions = <FeedPortion>[];
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map || value['as_fed_kg'] is! num)
        throw const FormatException('Takaran pakan dari layanan tidak valid.');
      final kg = (value['as_fed_kg'] as num).toDouble();
      if (!kg.isFinite || kg < 0 || !feeds.contains(entry.key))
        throw const FormatException(
            'Bahan atau takaran pakan dari layanan tidak sesuai.');
      final dm = _optionalNumber(value['dry_matter_kg']);
      final ratio = _optionalNumber(value['ratio_dm']);
      if (dm != null && (!dm.isFinite || dm < 0) ||
          ratio != null && (!ratio.isFinite || ratio < 0 || ratio > 100))
        throw const FormatException(
            'Komposisi pakan dari layanan tidak valid.');
      portions.add(FeedPortion(
          key: entry.key.toString(),
          asFedKg: kg,
          dryMatterKg: dm,
          ratio: ratio));
    }
    if (portions.every((p) => p.asFedKg == 0))
      throw const FormatException(
          'Layanan mengembalikan takaran nol. Coba hitung ulang.');
    final total = _optionalNumber(data['total_dry_matter_kg']);
    if (total != null && (!total.isFinite || total <= 0))
      throw const FormatException('Total bahan kering tidak valid.');
    final responseWeight = _optionalNumber(data['weight_kg']);
    if (responseWeight != null &&
            (responseWeight - cattle.estimatedWeight!).abs() > .01 ||
        data['target'] != null && data['target'] != target)
      throw const FormatException(
          'Hasil pakan tidak cocok dengan input. Coba hitung ulang.');
    final now = DateTime.now();
    return FeedPlan(
        id: '${now.microsecondsSinceEpoch}-${_idCounter++}',
        cattleId: cattle.id,
        cattleName: cattle.nameOrId,
        weightKg: cattle.estimatedWeight!,
        ageMonths: cattle.ageMonths,
        gender: cattle.gender,
        bodyCondition: condition,
        target: target,
        availableFeeds: List.of(feeds),
        createdAt: now,
        weightDate: cattle.history.isEmpty ? null : cattle.history.last.date,
        portions: portions,
        totalDryMatterKg: total,
        warning: data['warning']?.toString(),
        notes: data['notes'] is List
            ? (data['notes'] as List).map((e) => e.toString()).toList()
            : data['notes'] == null
                ? []
                : [data['notes'].toString()]);
  }
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
  factory FeedPlan.fromJson(Map<String, dynamic> j) => FeedPlan(
      id: j['id'],
      cattleId: j['cattleId'],
      cattleName: j['cattleName'],
      weightKg: (j['weightKg'] as num).toDouble(),
      ageMonths: j['ageMonths'],
      gender: j['gender'],
      bodyCondition: j['bodyCondition'],
      target: j['target'],
      availableFeeds: List<String>.from(j['availableFeeds']),
      createdAt: DateTime.parse(j['createdAt']),
      weightDate:
          j['weightDate'] == null ? null : DateTime.parse(j['weightDate']),
      portions: (j['portions'] as List)
          .map((p) => FeedPortion.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      totalDryMatterKg: (j['totalDryMatterKg'] as num?)?.toDouble(),
      warning: j['warning'],
      notes: List<String>.from(j['notes'] ?? []));
}
