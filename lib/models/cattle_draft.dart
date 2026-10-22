import 'selected_image.dart';

class WeightRecord {
  const WeightRecord(
      {required this.weightKg, required this.date, this.source = 'unknown'});

  final double weightKg;
  final DateTime date;
  final String source;
  String get sourceLabel =>
      {
        'ai': 'Estimasi foto AI',
        'manual': 'Timbangan manual',
        'demo': 'Data contoh',
        'unknown': 'Catatan bobot'
      }[source] ??
      'Catatan bobot';
}

class CattleDraft {
  const CattleDraft({
    required this.nameOrId,
    this.id = '',
    required this.gender,
    required this.ageMonths,
    this.notes = '',
    this.images = const [],
    this.latestCheckImages = const [],
    this.estimatedWeight,
    this.predictionSpread,
    this.validImages = 0,
    this.rejectedImages = 0,
    this.history = const [],
    this.placeholderEmoji = '🐄',
  });

  final String id;
  final String nameOrId;
  final String gender;
  final int ageMonths;
  final String notes;

  final List<SelectedImage> images;
  final List<SelectedImage> latestCheckImages;

  final double? estimatedWeight;
  final double? predictionSpread;

  final int validImages;
  final int rejectedImages;

  final List<WeightRecord> history;

  final String placeholderEmoji;

  CattleDraft copyWith({
    String? id,
    String? nameOrId,
    String? gender,
    int? ageMonths,
    String? notes,
    List<SelectedImage>? images,
    List<SelectedImage>? latestCheckImages,
    double? estimatedWeight,
    double? predictionSpread,
    bool clearPrediction = false,
    int? validImages,
    int? rejectedImages,
    List<WeightRecord>? history,
    String? placeholderEmoji,
  }) {
    return CattleDraft(
      id: id ?? this.id,
      nameOrId: nameOrId ?? this.nameOrId,
      gender: gender ?? this.gender,
      ageMonths: ageMonths ?? this.ageMonths,
      notes: notes ?? this.notes,
      images: images ?? this.images,
      latestCheckImages: latestCheckImages ?? this.latestCheckImages,
      estimatedWeight: estimatedWeight ?? this.estimatedWeight,
      predictionSpread:
          clearPrediction ? null : predictionSpread ?? this.predictionSpread,
      validImages: validImages ?? this.validImages,
      rejectedImages: rejectedImages ?? this.rejectedImages,
      history: history ?? this.history,
      placeholderEmoji: placeholderEmoji ?? this.placeholderEmoji,
    );
  }
}
