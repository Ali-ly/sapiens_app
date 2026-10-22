import 'selected_image.dart';
import 'weight_record.dart';

export 'weight_record.dart';

class Cattle {
  Cattle({
    required this.nameOrId,
    this.id = '',
    required this.gender,
    required this.ageMonths,
    this.notes = '',
    List<SelectedImage> images = const [],
    List<SelectedImage> latestCheckImages = const [],
    this.estimatedWeight,
    this.predictionSpread,
    this.validImages = 0,
    this.rejectedImages = 0,
    List<WeightRecord> history = const [],
  })  : images = List.unmodifiable(images),
        latestCheckImages = List.unmodifiable(latestCheckImages),
        history = List.unmodifiable(history);

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

  Cattle copyWith({
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
  }) {
    return Cattle(
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
    );
  }
}
