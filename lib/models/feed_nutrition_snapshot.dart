import 'feed_api_v2.dart';
import 'production.dart';

/// Immutable evidence from a v2 evaluation, not a generated ration or a claim
/// that the ration is adequate. Category comes from the evaluated request.
class FeedNutritionSnapshot {
  FeedNutritionSnapshot({
    required this.productionCategory,
    required this.response,
  }) {
    if (response.productionCategory != null &&
        response.productionCategory != productionCategory) {
      throw const FormatException('Kategori snapshot nutrisi tidak sesuai.');
    }
  }

  static const version = 1;
  final ProductionCategory productionCategory;
  final NutritionResponse response;
  Object? get requirement => response.requirement;
  Object? get supply => response.supply;
  Object? get adequacy => response.adequacy;
  Object? get warnings => response.warnings;
  Object? get coverage => response.coverage;
  Object? get assumptions => response.assumptions;
  Object? get defaultsUsed => response.defaultsUsed;

  Map<String, dynamic> toJson() => {
        'version': version,
        'productionCategory': productionCategory.name,
        'response': response.toJson(),
      };

  factory FeedNutritionSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] is! int ||
        json['version'] != version ||
        json.keys.any((key) =>
            !{'version', 'productionCategory', 'response'}.contains(key)) ||
        json['response'] is! Map<String, dynamic>) {
      throw const FormatException(
          'Versi/format snapshot nutrisi belum didukung.');
    }
    final category = switch (json['productionCategory']) {
      'beef' => ProductionCategory.beef,
      'dairy' => ProductionCategory.dairy,
      _ =>
        throw const FormatException('Kategori snapshot nutrisi tidak valid.'),
    };
    return FeedNutritionSnapshot(
      productionCategory: category,
      response:
          NutritionResponse.fromJson(json['response'] as Map<String, dynamic>),
    );
  }
}
