import 'dart:typed_data';

import '../domain/value.dart';

class UploadPhoto {
  UploadPhoto({required this.name, required List<int> bytes})
      : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String name;
  final Uint8List bytes;
}

class WeightEstimate {
  WeightEstimate(
      {required this.kg,
      required this.accepted,
      required this.rejected,
      required Json raw})
      : raw = frozenJson(raw);
  final double kg;
  final List<UploadPhoto> accepted;
  final List<String> rejected;
  final Json raw;
  factory WeightEstimate.parse(Json j, List<UploadPhoto> sent) {
    require(j['estimated_weight_kg'] is num,
        'Estimasi bobot dari layanan tidak valid.');
    final kg = (j['estimated_weight_kg'] as num).toDouble();
    positive(kg, 'Estimasi bobot');
    final rejects = j['rejected_files'];
    require(rejects == null || rejects is List,
        'Respons penolakan foto tidak valid.');
    final rejected = List<String>.from((rejects as List?) ?? []);
    require(
        rejected.toSet().length == rejected.length &&
            rejected.every((n) => sent.any((p) => p.name == n)),
        'Backend mengembalikan identitas foto yang tidak sesuai.');
    final accepted = sent.where((p) => !rejected.contains(p.name)).toList();
    final count = j['num_valid_images'];
    require(
        accepted.isNotEmpty &&
            (count == null || count is int && count == accepted.length),
        'Foto valid pada respons tidak sesuai unggahan.');
    final spread = j['prediction_spread_kg'];
    require(spread == null || spread is num && spread.isFinite && spread >= 0,
        'Kualitas estimasi tidak valid.');
    return WeightEstimate(
        kg: kg,
        accepted: List.unmodifiable(accepted),
        rejected: List.unmodifiable(rejected),
        raw: j);
  }
}

class FeedIngredient {
  FeedIngredient(
      {required this.id,
      required this.name,
      required this.category,
      required this.profileStatus,
      required List<FarmMode> validFor,
      required Json raw})
      : validFor = List.unmodifiable(validFor),
        raw = frozenJson(raw);
  final String id, name, category, profileStatus;
  final List<FarmMode> validFor;
  final Json raw;
  factory FeedIngredient.fromJson(Json j) {
    require(
        j['feed_id'] is String &&
            j['display_name'] is String &&
            j['valid_for'] is List,
        'Katalog bahan tidak valid.');
    require(
        (j['feed_id'] as String).isNotEmpty &&
            (j['display_name'] as String).trim().isNotEmpty,
        'Identitas bahan tidak lengkap.');
    require((j['valid_for'] as List).every((v) => v is String),
        'Validitas bahan tidak dapat dibaca.');
    final valid = (j['valid_for'] as List)
        .where((v) => FarmMode.values.any((m) => m.name == v))
        .map((v) => FarmMode.values.byName(v as String))
        .toList();
    return FeedIngredient(
        id: j['feed_id'] as String,
        name: j['display_name'] as String,
        category: j['category'] as String? ?? 'other',
        profileStatus: j['profile_status'] as String? ?? 'unknown',
        validFor: valid,
        raw: j);
  }
  bool get productSpecific => profileStatus == 'product_specific';
}

class FeedAmount {
  const FeedAmount(this.feedId, this.kg);
  final String feedId;
  final double kg;
  Json toJson() => {'feed_id': feedId, 'as_fed_kg_day': kg};
}

class GatewayError implements Exception {
  const GatewayError(this.message, {this.statusCode, this.details});
  final String message;
  final int? statusCode;
  final Object? details;
  @override
  String toString() => message;
}

abstract interface class Gateway {
  Future<Json> health();
  Future<List<FeedIngredient>> feeds(FarmMode mode);
  Future<Json> nutrition(Json request);
  Future<WeightEstimate> weight(List<UploadPhoto> photos);
}
