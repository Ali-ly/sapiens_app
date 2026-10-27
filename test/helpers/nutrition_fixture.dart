import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_api_v2.dart';

Future<FeedCatalogResponse> loadNutritionCatalog({
  required ProductionCategory productionCategory,
}) async =>
    FeedCatalogResponse.fromJson({
      'production_category': productionCategory.name,
      'count': 1,
      'feeds': [
        {
          'feed_id': 'rumput_gajah',
          'display_name': 'Rumput gajah',
          'category': 'forage',
          'valid_for': [productionCategory.name],
          'profile_status': 'partial'
        }
      ],
    });

Future<NutritionResponse> evaluateNutrition(
        {required NutritionRequest request}) async =>
    NutritionResponse.fromJson({
      'production_category': request.productionCategory.name,
      'warnings': ['Partial data'],
      'coverage': {'status': 'partial'}
    });
