// Presentation only: interpret explicit backend outcomes, never calculate nutrition.
import '../../domain/records.dart';

Map<String, dynamic> resultMap(Object? value) => value is Map
    ? {for (final e in value.entries) e.key.toString(): e.value}
    : {};
double? resultNumber(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.toDouble() : null;

class NutrientComparison {
  NutrientComparison(this.key, this.data, {required this.dairyLimited});
  final String key;
  final Map<String, dynamic> data;
  final bool dairyLimited;
  String get title =>
      const {
        'dry_matter': 'Bahan kering',
        'dry_matter_intake': 'Konsumsi bahan kering',
        'tdn': 'Energi (TDN)',
        'energy': 'Energi',
        'crude_protein': 'Protein kasar',
        'protein': 'Protein',
        'calcium': 'Kalsium',
        'phosphorus': 'Fosfor',
      }[key] ??
      'Komponen tambahan';
  String get status => data['status']?.toString() ?? '';
  bool get intake => key == 'dry_matter_intake';
  double? get requirement =>
      resultNumber(data[intake ? 'predicted_dmi_kg_day' : 'requirement']);
  double? get supply =>
      resultNumber(data[intake ? 'ration_dm_kg_day' : 'supply']);
  double? get percentage => resultNumber(data['adequacy_pct']);
  double? get coverage => resultNumber(data['profile_coverage_fraction']);
  String? get unit => intake
      ? 'kg/hari'
      : const {
          'kg/day': 'kg/hari',
          'kg_day': 'kg/hari',
          'kg/hari': 'kg/hari',
          'g/day': 'g/hari',
          'g_day': 'g/hari',
          'g/hari': 'g/hari',
          'Mcal/day': 'Mcal/hari',
          'Mcal/hari': 'Mcal/hari',
        }[data['unit']];
  String? get displayUnit =>
      unit == 'kg/hari' && (key == 'dry_matter' || intake)
          ? 'kg BK/hari'
          : unit == 'kg/hari' && key == 'tdn'
              ? 'kg TDN/hari'
              : unit;
  bool get comparable =>
      requirement != null &&
      supply != null &&
      unit != null &&
      status != 'not_fully_evaluable' &&
      (coverage == null || coverage! >= 1) &&
      (!dairyLimited || intake) &&
      {
        'deficient',
        'insufficient',
        'adequate',
        'sufficient',
        'excess',
        'excessive',
        'below_predicted_intake',
        'above_predicted_intake',
        'within_predicted_intake',
        'near_predicted_intake'
      }.contains(status);
  bool get deficient =>
      comparable && {'deficient', 'insufficient'}.contains(status);
  bool get sufficient =>
      comparable && {'adequate', 'sufficient'}.contains(status);
  bool get excess => comparable && {'excess', 'excessive'}.contains(status);
  String get statusLabel => !comparable
      ? 'Belum dapat dinilai'
      : const {
          'deficient': 'Kurang',
          'insufficient': 'Kurang',
          'adequate': 'Cukup',
          'sufficient': 'Cukup',
          'excess': 'Berlebih',
          'excessive': 'Berlebih',
          'below_predicted_intake': 'Di bawah perkiraan konsumsi',
          'above_predicted_intake': 'Di atas perkiraan konsumsi',
          'within_predicted_intake': 'Dalam perkiraan konsumsi',
          'near_predicted_intake': 'Mendekati perkiraan konsumsi',
        }[status]!;
  String get explanation {
    if (coverage != null && coverage! < 1) {
      return 'Profil nutrisi bahan belum lengkap. Pasokan $title belum dapat dihitung penuh; angka nol tidak berarti bahan ini tidak mengandungnya.';
    }
    final reason = data['reason']?.toString() ?? '';
    if (reason.contains('NEL') && reason.contains('TDN')) {
      return 'Kebutuhan dan data pakan memakai sistem energi berbeda (NEL dan TDN), sehingga belum bisa dibandingkan.';
    }
    if (reason.contains('MP/RDP/RUP')) {
      return 'Data protein pakan yang diperlukan layanan belum tersedia untuk perbandingan ini.';
    }
    return 'Layanan belum memberikan data pembanding yang lengkap untuk $title.';
  }
}

class FeedResultPresentation {
  FeedResultPresentation(this.evaluation) {
    final response = evaluation.response;
    final dairy = evaluation.request['production_category'] == 'dairy';
    bool limited(Object? v) =>
        v == 'not_fully_evaluable' ||
        v is Map &&
            v.entries.any((e) =>
                e.key == 'not_fully_evaluable' && e.value == true ||
                limited(e.value)) ||
        v is List && v.any(limited);
    dairyLimited = dairy && limited(response);
    comparisons = resultMap(response['adequacy'])
        .entries
        .where((e) =>
            e.value is Map &&
            ['status', 'requirement', 'supply', 'predicted_dmi_kg_day']
                .any((key) => resultMap(e.value).containsKey(key)))
        .map((e) => NutrientComparison(e.key, resultMap(e.value),
            dairyLimited: dairyLimited))
        .toList();
  }
  final NutritionEvaluation evaluation;
  late final bool dairyLimited;
  late final List<NutrientComparison> comparisons;
  List<NutrientComparison> get available =>
      comparisons.where((r) => r.comparable).toList();
  List<NutrientComparison> get unavailable =>
      comparisons.where((r) => !r.comparable).toList();
  int get deficientCount => available.where((r) => r.deficient).length;
  String get headline {
    if (evaluation.response['status'] == 'not_implemented') {
      return 'Konteks ini belum didukung layanan';
    }
    if (evaluation.response['status'] == 'insufficient_data') {
      return 'Data untuk evaluasi belum lengkap';
    }
    if (dairyLimited) return 'Belum dapat dievaluasi penuh';
    if (skippedCount > 0) return 'Belum semua bahan ikut dihitung';
    if (deficientCount > 0) return 'Pakan yang dihitung masih kurang';
    if (available.any((r) => r.excess)) {
      return 'Ada komponen melebihi kebutuhan';
    }
    if (unavailable.isNotEmpty) return 'Sebagian hasil belum bisa dinilai';
    if (available.isNotEmpty && available.every((r) => r.sufficient)) {
      return 'Kebutuhan yang dinilai sudah tercukupi';
    }
    return 'Hasil belum dapat disimpulkan';
  }

  int get skippedCount =>
      supplyItems.where((item) => item['supply_evaluable'] == false).length;
  String get summary {
    final skipped = skippedCount == 1
        ? '${feedName(supplyItems.firstWhere((item) => item['supply_evaluable'] == false)['feed_id']?.toString() ?? '')} belum ikut dihitung. '
        : skippedCount > 0
            ? '$skippedCount bahan belum ikut dihitung. '
            : '';
    if (dairyLimited) {
      return '${skipped}Perbandingan konsumsi bahan kering tersedia bila datanya lengkap. Kecukupan nutrien lain belum dapat disimpulkan.';
    }
    if (comparisons.isEmpty) {
      return '${skipped}Layanan belum memberikan perbandingan kebutuhan dan pasokan. Lihat catatan layanan di bawah.';
    }
    final parts = <String>[
      if (deficientCount > 0) '$deficientCount komponen kurang',
      if (available.any((r) => r.sufficient))
        '${available.where((r) => r.sufficient).length} cukup',
      if (available.any((r) => r.excess))
        '${available.where((r) => r.excess).length} berlebih',
      if (unavailable.isNotEmpty) '${unavailable.length} belum dapat dinilai',
    ];
    return '$skipped${parts.isEmpty ? 'Perbandingan tersedia' : parts.join(' · ')}. Hasil hanya mencakup bahan yang berhasil dihitung.';
  }

  Map<String, dynamic> get supply => resultMap(
      evaluation.response['supply'] ?? evaluation.response['feed_supply']);
  List<Map<String, dynamic>> get feedInputs =>
      (evaluation.request['feed_items'] is List
              ? evaluation.request['feed_items'] as List
              : const [])
          .whereType<Map>()
          .map(resultMap)
          .toList();
  List<Map<String, dynamic>> get supplyItems =>
      (supply['items'] is List ? supply['items'] as List : const [])
          .whereType<Map>()
          .map(resultMap)
          .toList();
  String feedName(String id) {
    final known = evaluation.feedNames[id];
    if (known != null) return known;
    for (final item in supplyItems) {
      if (item['feed_id'] == id && item['display_name'] is String) {
        return item['display_name'] as String;
      }
    }
    return 'Bahan pakan';
  }

  List<String> get warnings {
    final all = <String>{};
    for (final raw in [
      evaluation.response['warnings'],
      supply['warnings'],
      evaluation.response['message']
    ]) {
      final rows = raw is List
          ? raw
          : raw == null
              ? const []
              : [raw];
      for (final value in rows) {
        if (value is! String || value.trim().isEmpty) continue;
        if (RegExp(
                r'^(dry_matter|tdn|crude_protein) diperkirakan belum memenuhi kebutuhan')
            .hasMatch(value)) continue;
        if (RegExp(r'^(calcium|phosphorus) belum dapat dinilai')
            .hasMatch(value)) continue;
        var text = value;
        if (value.contains('conditional/default profile')) {
          text =
              '${value.split(':').first} dihitung menggunakan profil nutrisi referensi dari layanan.';
        } else if (value.contains('dry_matter_pct_as_fed') &&
            value.contains('tidak dihitung')) {
          final id = value.split(':').first;
          text =
              '${feedName(id)} belum ikut dihitung karena kadar bahan keringnya belum cukup terverifikasi.';
        } else if (value.contains('NEL') && value.contains('TDN')) {
          text =
              'Energi belum bisa dibandingkan: kebutuhan dan data pakan memakai sistem energi berbeda (NEL dan TDN).';
        } else if (value.contains('MP/RDP/RUP')) {
          text =
              'Kecukupan protein belum bisa dinilai karena data protein pakan yang diperlukan belum tersedia.';
        }
        all.add(text);
      }
    }
    return all.toList();
  }
}
