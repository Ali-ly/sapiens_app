import '../models/feed_plan.dart';

/// Validated per-head ration shared by individual and bulk flows.
class FeedRation {
  FeedRation(
      {required List<FeedPortion> portions,
      this.totalDryMatterKg,
      this.warning,
      required List<String> notes})
      : portions = List.unmodifiable(portions),
        notes = List.unmodifiable(notes);
  final List<FeedPortion> portions;
  final double? totalDryMatterKg;
  final String? warning;
  final List<String> notes;
  static double? _optionalNumber(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is! num || !value.isFinite) {
      throw const FormatException('Angka dari layanan pakan tidak valid.');
    }
    return value.toDouble();
  }

  static FeedRation parse(
      {required double weight,
      required String target,
      required List<String> feeds,
      required Map<String, dynamic> data}) {
    if (!weight.isFinite ||
        weight < 1 ||
        weight > 2000 ||
        !targetLabels.containsKey(target) ||
        feeds.isEmpty ||
        feeds.toSet().length != feeds.length ||
        feeds.any((key) => !feedLabels.containsKey(key))) {
      throw const FormatException('Input pakan tidak valid.');
    }
    final raw = data['recommendation'];
    if (raw is! Map || raw.isEmpty) {
      throw const FormatException(
        'Layanan pakan belum mengembalikan takaran yang dapat digunakan.',
      );
    }
    final portions = <FeedPortion>[];
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map || value['as_fed_kg'] is! num) {
        throw const FormatException('Takaran pakan dari layanan tidak valid.');
      }
      final kg = (value['as_fed_kg'] as num).toDouble();
      if (!kg.isFinite || kg < 0 || !feeds.contains(entry.key)) {
        throw const FormatException(
          'Bahan atau takaran pakan dari layanan tidak sesuai.',
        );
      }
      final dm = _optionalNumber(value['dry_matter_kg']);
      final ratio = _optionalNumber(value['ratio_dm']);
      if (dm != null && (!dm.isFinite || dm < 0) ||
          ratio != null && (!ratio.isFinite || ratio < 0 || ratio > 100)) {
        throw const FormatException(
          'Komposisi pakan dari layanan tidak valid.',
        );
      }
      portions.add(
        FeedPortion(
          key: entry.key.toString(),
          asFedKg: kg,
          dryMatterKg: dm,
          ratio: ratio,
        ),
      );
    }
    if (portions.every((p) => p.asFedKg == 0)) {
      throw const FormatException(
        'Layanan mengembalikan takaran nol. Coba hitung ulang.',
      );
    }
    final total = _optionalNumber(data['total_dry_matter_kg']);
    if (total != null && (!total.isFinite || total <= 0)) {
      throw const FormatException('Total bahan kering tidak valid.');
    }
    final responseWeight = _optionalNumber(data['weight_kg']);
    if (responseWeight != null && (responseWeight - weight).abs() > .01 ||
        data['target'] != null && data['target'] != target) {
      throw const FormatException(
        'Hasil pakan tidak cocok dengan input. Coba hitung ulang.',
      );
    }
    return FeedRation(
      portions: portions,
      totalDryMatterKg: total,
      warning: data['warning']?.toString(),
      notes: data['notes'] is List
          ? (data['notes'] as List).map((e) => e.toString()).toList()
          : data['notes'] == null
              ? []
              : [data['notes'].toString()],
    );
  }
}
