import 'cattle_rules.dart';

/// A validated response from the image-based weight endpoint.
class WeightEstimate {
  const WeightEstimate._(
      {required this.weightKg,
      required this.validImages,
      required this.rejectedImages,
      this.predictionSpread});
  final double weightKg;
  final double? predictionSpread;
  final int validImages, rejectedImages;

  factory WeightEstimate.fromJson(Map<String, dynamic> json,
      {required int imageCount}) {
    final weight = json['estimated_weight_kg'];
    if (weight is! num || !CattleRules.isValidWeight(weight.toDouble())) {
      throw const FormatException(
        'Layanan belum menghasilkan bobot yang valid. Coba foto lain.',
      );
    }
    final spread = json['prediction_spread_kg'];
    if (spread != null && (spread is! num || !spread.isFinite || spread < 0)) {
      throw const FormatException('Variasi prediksi dari layanan tidak valid.');
    }
    final valid = json['num_valid_images'] ?? 0;
    final rejected = json['rejected_files'] ?? const [];
    if (valid is! int ||
        valid < 0 ||
        valid > imageCount ||
        rejected is! List ||
        rejected.length + valid > imageCount) {
      throw const FormatException(
        'Jumlah foto dari layanan estimasi tidak valid.',
      );
    }
    return WeightEstimate._(
      weightKg: weight.toDouble(),
      predictionSpread: (spread as num?)?.toDouble(),
      validImages: valid,
      rejectedImages: rejected.length,
    );
  }
}
