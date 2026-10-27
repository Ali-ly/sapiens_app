import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sapita_app/models/feed_api_v2.dart';
import 'package:sapita_app/models/production.dart';
import 'package:sapita_app/services/api_response.dart';
import 'package:sapita_app/services/feed_service.dart';

void main() {
  NutritionRequest request({bool dairy = false}) => NutritionRequest(
      cattle: dairy
          ? NutritionCattleContext.dairy(
              bodyWeightKg: 450,
              dairyStage: 'fresh',
              dim: 0,
              milkKgDay: 12,
              parityGroup: 'multiparous',
              milkFatPct: 4,
              milkProteinPct: 3)
          : NutritionCattleContext.beef(
              bodyWeightKg: 300, purpose: 'penggemukan', targetAdgKgDay: .5),
      feedItems: [NutritionFeedItem(feedId: 'rumput_gajah', asFedKgDay: 25)]);

  for (final category in ProductionCategory.values) {
    test(
        'GET v2 catalog ${category.name}, nutrients optional and metadata retained',
        () async {
      final payload = {
        'production_category': category.name,
        'count': 1,
        'feeds': [
          {
            'feed_id': 'rumput_gajah',
            'display_name': 'Rumput gajah',
            'category': 'forage',
            'valid_for': ['beef', 'dairy'],
            'profile_status': 'partial',
            'crude_protein_pct_dm': 10,
            'confidence_note': null,
            'future': {'source': 'backend'}
          }
        ],
      };
      final client = MockClient((r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/v2/feeds/${category.name}');
        return http.Response(jsonEncode(payload), 200);
      });
      addTearDown(client.close);
      final catalog = await FeedService.fetchFeeds(
          productionCategory: category, client: client);
      expect(catalog.toJson(), payload);
      expect(catalog.feeds.single.crudeProteinPctDm, 10);
      expect(catalog.feeds.single.dryMatterPctAsFed, isNull);
      expect(() => (catalog.feeds.single.data['future'] as Map)['source'] = 'x',
          throwsUnsupportedError);
    });
  }

  test('Beef nutrition serializes the supplied v2 contract exactly', () async {
    final client = MockClient((r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/v2/nutrition');
      expect(r.headers['content-type'], 'application/json');
      expect(jsonDecode(r.body), {
        'production_category': 'beef',
        'cattle': {
          'body_weight_kg': 300,
          'purpose': 'penggemukan',
          'target_adg_kg_day': .5
        },
        'feed_items': [
          {'feed_id': 'rumput_gajah', 'as_fed_kg_day': 25}
        ],
      });
      return http.Response(
          '{"production_category":"beef","supply":{"dm":5},"coverage":{"partial":true},"new_field":[1]}',
          200);
    });
    addTearDown(client.close);
    final result = await FeedService.calculateNutrition(
        request: request(), client: client);
    expect(result.supply, {'dm': 5});
    expect(result.requirement, isNull);
    expect(result.toJson()['new_field'], [1]);
    expect(() => (result.supply as Map)['dm'] = 6, throwsUnsupportedError);
    // Service must leave an injected client open.
    await FeedService.calculateNutrition(request: request(), client: client);
  });

  test('Dairy sends lactation context and never silently routes to Beef',
      () async {
    final client = MockClient((r) async {
      final j = jsonDecode(r.body) as Map;
      expect(j['production_category'], 'dairy');
      expect(j['cattle'], {
        'body_weight_kg': 450,
        'dairy_stage': 'fresh',
        'dim': 0,
        'milk_kg_day': 12,
        'parity_group': 'multiparous',
        'milk_fat_pct': 4,
        'milk_protein_pct': 3
      });
      return http.Response(
          '{"production_category":"dairy","warnings":[],"defaults_used":null}',
          200);
    });
    addTearDown(client.close);
    expect(
        (await FeedService.calculateNutrition(
                request: request(dairy: true), client: client))
            .productionCategory,
        ProductionCategory.dairy);
    expect(NutritionCattleContext.dairy(bodyWeightKg: 400).toJson(),
        {'body_weight_kg': 400});
  });

  test('Optional nutrition sections are opaque, lossless and not invented', () {
    for (final j in <Map<String, dynamic>>[
      {},
      {
        'requirement': null,
        'assumptions': ['manual']
      },
      {
        'adequacy': {
          'energy': {'status': 'unknown'}
        },
        'coverage': ['partial'],
        'defaults_used': {'x': 2}
      },
    ]) {
      expect(NutritionResponse.fromJson(j).toJson(), j);
    }
  });

  test('Invalid ingredients and nonfinite request quantities rejected', () {
    expect(
        () => FeedIngredient.fromJson({'feed_id': 'x'}), throwsFormatException);
    expect(
        () => FeedIngredient.fromJson(
            {'feed_id': 'x', 'display_name': 'X', 'tdn_pct_dm': 'bad'}),
        throwsFormatException);
    expect(() => NutritionFeedItem(feedId: 'x', asFedKgDay: double.nan),
        throwsFormatException);
    expect(() => NutritionFeedItem(feedId: 'x', asFedKgDay: -1),
        throwsFormatException);
    expect(() => NutritionCattleContext.beef(bodyWeightKg: 0),
        throwsFormatException);
    expect(() => NutritionCattleContext.dairy(bodyWeightKg: 400, dim: -1),
        throwsFormatException);
  });

  test('Category mismatch and malformed catalog rejected', () async {
    final client = MockClient((_) async => http.Response(
        '{"production_category":"dairy","count":0,"feeds":[]}', 200));
    addTearDown(client.close);
    await expectLater(
        FeedService.fetchFeeds(
            productionCategory: ProductionCategory.beef, client: client),
        throwsFormatException);
    await expectLater(
        FeedService.calculateNutrition(request: request(), client: client),
        throwsFormatException);
    expect(
        () => FeedCatalogResponse.fromJson({
              'production_category': 'beef',
              'count': 1,
              'feeds': [3]
            }),
        throwsFormatException);
  });

  test('HTTP errors, malformed JSON and connection failure do not fallback',
      () async {
    for (final response in [
      http.Response('{"detail":{"message":"Dairy unsupported"}}', 422),
      http.Response('<html>offline</html>', 502)
    ]) {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return response;
      });
      addTearDown(client.close);
      await expectLater(
          FeedService.calculateNutrition(request: request(), client: client),
          response.statusCode == 422
              ? throwsA(isA<ApiException>()
                  .having((e) => e.statusCode, 'status', 422)
                  .having((e) => e.message, 'message', 'Dairy unsupported'))
              : throwsFormatException);
      expect(calls, 1);
    }
    final client =
        MockClient((_) async => throw http.ClientException('offline'));
    addTearDown(client.close);
    await expectLater(
        FeedService.fetchFeeds(
            productionCategory: ProductionCategory.beef, client: client),
        throwsA(isA<ApiException>()));
  });
}
