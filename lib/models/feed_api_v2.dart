import 'production.dart';

// API DTOs only: these are not persisted FeedPlan/domain snapshots.
Object? _freezeJson(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
        value.map((k, v) => MapEntry(k, _freezeJson(v))));
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freezeJson));
  if (value == null ||
      value is String ||
      value is bool ||
      value is num && value.isFinite) return value;
  throw const FormatException('Nilai JSON API tidak valid.');
}

Map<String, dynamic> _json(Map<String, dynamic> value) =>
    _freezeJson(value) as Map<String, dynamic>;

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Field $key tidak valid.');
  }
  return value;
}

double? _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num || !value.isFinite) {
    throw FormatException('Field $key bukan angka yang valid.');
  }
  return value.toDouble();
}

ProductionCategory _category(Object? value) => switch (value) {
      'beef' => ProductionCategory.beef,
      'dairy' => ProductionCategory.dairy,
      _ => throw const FormatException('Production category API tidak valid.'),
    };

class FeedIngredient {
  FeedIngredient.fromJson(Map<String, dynamic> json)
      : feedId = _text(json, 'feed_id'),
        displayName = _text(json, 'display_name'),
        data = _json(json) {
    for (final key in _nutrients) {
      _number(json, key);
    }
  }

  final String feedId;
  final String displayName;
  // Preserve optional and future backend metadata without inventing defaults.
  final Map<String, dynamic> data;
  Object? get category => data['category'];
  Object? get validFor => data['valid_for'];
  Object? get profileStatus => data['profile_status'];
  Object? get confidenceNote => data['confidence_note'];
  double? get dryMatterPctAsFed => _number(data, 'dry_matter_pct_as_fed');
  double? get crudeProteinPctDm => _number(data, 'crude_protein_pct_dm');
  double? get tdnPctDm => _number(data, 'tdn_pct_dm');
  double? get ndfPctDm => _number(data, 'ndf_pct_dm');
  double? get adfPctDm => _number(data, 'adf_pct_dm');
  double? get calciumPctDm => _number(data, 'calcium_pct_dm');
  double? get phosphorusPctDm => _number(data, 'phosphorus_pct_dm');
  Map<String, dynamic> toJson() => Map.of(data);
  static const _nutrients = [
    'dry_matter_pct_as_fed',
    'crude_protein_pct_dm',
    'tdn_pct_dm',
    'ndf_pct_dm',
    'adf_pct_dm',
    'calcium_pct_dm',
    'phosphorus_pct_dm',
  ];
}

class FeedCatalogResponse {
  FeedCatalogResponse.fromJson(Map<String, dynamic> json)
      : productionCategory = _category(json['production_category']),
        data = _json(json) {
    final rawCount = json['count'];
    final rawFeeds = json['feeds'];
    if (rawCount is! int || rawCount < 0 || rawFeeds is! List) {
      throw const FormatException('Katalog pakan tidak valid.');
    }
    count = rawCount;
    feeds = List.unmodifiable(rawFeeds.map((feed) {
      if (feed is! Map<String, dynamic>) {
        throw const FormatException('Bahan pakan tidak valid.');
      }
      return FeedIngredient.fromJson(feed);
    }));
  }
  final ProductionCategory productionCategory;
  late final int count;
  late final List<FeedIngredient> feeds;
  final Map<String, dynamic> data;
  Map<String, dynamic> toJson() => Map.of(data);
}

class NutritionCattleContext {
  NutritionCattleContext.beef(
      {required double bodyWeightKg, String? purpose, double? targetAdgKgDay})
      : this._(ProductionCategory.beef, {
          'body_weight_kg': bodyWeightKg,
          if (purpose != null) 'purpose': purpose,
          if (targetAdgKgDay != null) 'target_adg_kg_day': targetAdgKgDay,
        });
  NutritionCattleContext.dairy(
      {required double bodyWeightKg,
      String? dairyStage,
      int? dim,
      double? milkKgDay,
      String? parityGroup,
      double? milkFatPct,
      double? milkProteinPct})
      : this._(ProductionCategory.dairy, {
          'body_weight_kg': bodyWeightKg,
          if (dairyStage != null) 'dairy_stage': dairyStage,
          if (dim != null) 'dim': dim,
          if (milkKgDay != null) 'milk_kg_day': milkKgDay,
          if (parityGroup != null) 'parity_group': parityGroup,
          if (milkFatPct != null) 'milk_fat_pct': milkFatPct,
          if (milkProteinPct != null) 'milk_protein_pct': milkProteinPct,
        });
  factory NutritionCattleContext.fromJson(
      ProductionCategory category, Map<String, dynamic> json) {
    for (final key in ['purpose', 'dairy_stage', 'parity_group']) {
      if (json[key] != null && json[key] is! String) {
        throw FormatException('Field $key tidak valid.');
      }
    }
    for (final key in [
      'target_adg_kg_day',
      'milk_kg_day',
      'milk_fat_pct',
      'milk_protein_pct'
    ]) {
      _number(json, key);
    }
    if (json['dim'] != null && json['dim'] is! int) {
      throw const FormatException('DIM tidak valid.');
    }
    return NutritionCattleContext._(category, json);
  }

  NutritionCattleContext._(this.productionCategory, Map<String, dynamic> json)
      : data = _json(json) {
    if ((_number(json, 'body_weight_kg') ?? 0) <= 0 ||
        json['dim'] is int && (json['dim'] as int) < 0 ||
        (_number(json, 'milk_kg_day') ?? 0) < 0) {
      throw const FormatException('Konteks sapi untuk nutrisi tidak valid.');
    }
  }
  final ProductionCategory productionCategory;
  final Map<String, dynamic> data;
  double get bodyWeightKg => _number(data, 'body_weight_kg')!;
  Map<String, dynamic> toJson() => Map.of(data);
}

class NutritionFeedItem {
  NutritionFeedItem({required this.feedId, required this.asFedKgDay}) {
    if (feedId.trim().isEmpty || !asFedKgDay.isFinite || asFedKgDay < 0) {
      throw const FormatException('Input bahan pakan tidak valid.');
    }
  }
  final String feedId;
  final double asFedKgDay;
  Map<String, dynamic> toJson() => {
        'feed_id': feedId,
        'as_fed_kg_day': asFedKgDay,
      };
}

class NutritionRequest {
  NutritionRequest(
      {required this.cattle, required List<NutritionFeedItem> feedItems})
      : feedItems = List.unmodifiable(feedItems);
  factory NutritionRequest.fromJson(Map<String, dynamic> json) {
    if (json.keys.any((key) =>
            !{'production_category', 'cattle', 'feed_items'}.contains(key)) ||
        json['cattle'] is! Map<String, dynamic> ||
        json['feed_items'] is! List) {
      throw const FormatException('Input evaluasi nutrisi tidak valid.');
    }
    return NutritionRequest(
      cattle: NutritionCattleContext.fromJson(
          _category(json['production_category']),
          json['cattle'] as Map<String, dynamic>),
      feedItems: (json['feed_items'] as List).map((item) {
        if (item is! Map<String, dynamic> ||
            item.keys
                .any((key) => !{'feed_id', 'as_fed_kg_day'}.contains(key))) {
          throw const FormatException('Bahan evaluasi nutrisi tidak valid.');
        }
        final amount = _number(item, 'as_fed_kg_day');
        if (amount == null) {
          throw const FormatException('Jumlah bahan belum tersedia.');
        }
        return NutritionFeedItem(
            feedId: _text(item, 'feed_id'), asFedKgDay: amount);
      }).toList(),
    );
  }

  final NutritionCattleContext cattle;
  ProductionCategory get productionCategory => cattle.productionCategory;
  final List<NutritionFeedItem> feedItems;
  Map<String, dynamic> toJson() => {
        'production_category': productionCategory.name,
        'cattle': cattle.toJson(),
        'feed_items': feedItems.map((item) => item.toJson()).toList(),
      };
}

/// Sections retain backend-owned JSON until their nested schemas are specified.
/// Missing/null sections remain absent/null, never zero or a synthetic ration.
class NutritionResponse {
  NutritionResponse.fromJson(Map<String, dynamic> json)
      : productionCategory = json['production_category'] == null
            ? null
            : _category(json['production_category']),
        data = _json(json);
  final ProductionCategory? productionCategory;
  final Map<String, dynamic> data;
  Object? get requirement => data['requirement'];
  Object? get supply => data['supply'];
  Object? get adequacy => data['adequacy'];
  Object? get warnings => data['warnings'];
  Object? get coverage => data['coverage'];
  Object? get assumptions => data['assumptions'];
  Object? get defaultsUsed => data['defaults_used'];
  Map<String, dynamic> toJson() => Map.of(data);
}
