import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cattle_app/models/cattle_draft.dart';
import 'package:cattle_app/models/feed_plan.dart';
import 'package:cattle_app/models/selected_image.dart';
import 'package:cattle_app/services/feed_service.dart';
import 'package:cattle_app/services/api_service.dart';
import 'package:cattle_app/state/farm_store.dart';

Map<String, dynamic> fixture() => Map<String, dynamic>.from(
    jsonDecode(File('test/fixtures/feed_response.json').readAsStringSync()));
void main() {
  late FarmStore store;
  String? memory;
  setUp(() async {
    memory = null;
    store = FarmStore(
        read: () async => memory,
        write: (s) async {
          memory = s;
        });
    await store.load();
  });
  Future<CattleDraft> cattle() => store.save(CattleDraft(
          nameOrId: 'B001 - Budi',
          gender: 'Jantan',
          ageMonths: 18,
          estimatedWeight: 350,
          history: [
            WeightRecord(weightKg: 350, date: DateTime.now(), source: 'manual')
          ]));
  FeedPlan plan(CattleDraft c) => FeedPlan.fromApi(
      cattle: c,
      target: 'penggemukan',
      condition: 'Sedang',
      feeds: ['rumput', 'jerami', 'dedak'],
      data: fixture());
  test('Live-response fixture parses fresh vs dry matter without mixing units',
      () async {
    final p = plan(await cattle());
    expect(p.totalFreshKg, closeTo(27.3, .001));
    expect(p.totalDryMatterKg, 8.75);
    expect(p.portions.first.ratio, 45);
    expect(p.bodyCondition, 'Sedang');
  });
  test('Feed service sends exactly the fields supported by the live API',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/calculate-feed');
      expect(jsonDecode(request.body), {
        'weight': 350.0,
        'target': 'penggemukan',
        'available_feeds': ['rumput', 'jerami', 'dedak']
      });
      return http.Response(jsonEncode(fixture()), 200);
    });
    await FeedService.calculateFeed(
        weight: 350,
        target: 'penggemukan',
        availableFeeds: ['rumput', 'jerami', 'dedak'],
        client: client);
    client.close();
  });
  test('Nested backend feed errors preserve the actionable message', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'detail': {'detail': 'Tambahkan rumput atau jerami.'}
        }),
        400));
    await expectLater(
        FeedService.calculateFeed(
            weight: 350,
            target: 'pemeliharaan',
            availableFeeds: ['dedak'],
            client: client),
        throwsA(predicate(
            (e) => e.toString().contains('Tambahkan rumput atau jerami.'))));
    client.close();
  });
  test('HTML gateway failures do not become a fake recommendation', () async {
    final client =
        MockClient((_) async => http.Response('<html>offline</html>', 502));
    await expectLater(
        FeedService.calculateFeed(
            weight: 350,
            target: 'pemeliharaan',
            availableFeeds: ['rumput'],
            client: client),
        throwsFormatException);
    client.close();
  });
  test('Invalid, zero, unselected or mismatched feed results are rejected',
      () async {
    final c = await cattle();
    for (final data in [
      <String, dynamic>{},
      {
        ...fixture(),
        'recommendation': {
          'rumput': {'as_fed_kg': -2}
        }
      },
      {
        ...fixture(),
        'recommendation': {
          'rumput': {'as_fed_kg': 0}
        }
      },
      {
        ...fixture(),
        'recommendation': {
          'unknown': {'as_fed_kg': 4}
        }
      },
      {...fixture(), 'weight_kg': 999}
    ]) {
      expect(
          () => FeedPlan.fromApi(
              cattle: c,
              target: 'penggemukan',
              condition: 'Tidak tahu',
              feeds: ['rumput', 'jerami', 'dedak'],
              data: data),
          throwsFormatException);
    }
  });
  test('Saved plans survive reload and become stale when the weight changes',
      () async {
    final c = await cattle();
    final p = plan(c);
    await store.savePlan(p);
    expect(store.planReady(c), isTrue);
    expect(store.dailyFeedTotals['rumput'], 22);
    final reloaded = FarmStore(read: () async => memory, write: (_) async {});
    await reloaded.load();
    expect(reloaded.latestPlan(c.id)!.bodyCondition, 'Sedang');
    expect(reloaded.planReady(reloaded.cattle.single), isTrue);
    final updated = await store.save(c.copyWith(estimatedWeight: 360, history: [
      ...c.history,
      WeightRecord(
          weightKg: 360,
          date: DateTime.now().add(const Duration(seconds: 1)),
          source: 'manual')
    ]));
    expect(store.planReady(updated), isFalse);
    expect(store.dailyFeedTotals, isEmpty);
    expect(store.feedPlans.length, 1);
    await expectLater(store.savePlan(p), throwsStateError);
  });
  test('Outdated weights are excluded from shopping totals', () async {
    final c = await store.save(CattleDraft(
        nameOrId: 'Old',
        gender: 'Jantan',
        ageMonths: 18,
        estimatedWeight: 350,
        history: [
          WeightRecord(
              weightKg: 350,
              date: DateTime.now().subtract(const Duration(days: 8)))
        ]));
    await store.savePlan(plan(c));
    expect(store.dailyFeedTotals, isEmpty);
  });
  test('Cattle deletion removes associated plans', () async {
    final c = await cattle();
    await store.savePlan(plan(c));
    await store.remove(c.id);
    expect(store.feedPlans, isEmpty);
  });
  test('Legacy storage without feedPlans is migrated without losing cattle',
      () async {
    final c = await cattle();
    final data = store.exportData()..remove('feedPlans');
    final legacy =
        FarmStore(read: () async => jsonEncode(data), write: (_) async {});
    await legacy.load();
    expect(legacy.error, isNull);
    expect(legacy.cattle.single.id, c.id);
    expect(legacy.feedPlans, isEmpty);
  });
  test(
      'Backup restores both cattle and feed plans; malformed backups are rejected',
      () async {
    final c = await cattle();
    await store.savePlan(plan(c));
    final raw = jsonEncode(store.exportData());
    final restored = FarmStore(read: () async => null, write: (_) async {});
    await restored.load();
    await restored.restoreBackup(raw);
    expect(restored.cattle.single.id, c.id);
    expect(restored.feedPlans.length, 1);
    expect(restored.dailyFeedTotals['dedak'], 3.9);
    final invalid = store.exportData();
    (invalid['cattle'] as List).add((invalid['cattle'] as List).first);
    expect(() => FarmStore.validateBackup(jsonEncode(invalid)),
        throwsFormatException);
    expect(
        () => FarmStore.validateBackup('broken json'), throwsFormatException);
  });
  test('A failed plan save does not mutate memory', () async {
    final c = await cattle();
    final failing = FarmStore(
        read: () async => memory,
        write: (_) async => throw Exception('quota exceeded'));
    await failing.load();
    await expectLater(failing.savePlan(plan(c)), throwsException);
    expect(failing.feedPlans, isEmpty);
  });
  test('Weight API parses multipart and rejects invalid numerical weights',
      () async {
    final image = SelectedImage(
        file: XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'cow.jpg'),
        bytes: Uint8List.fromList([1, 2, 3]));
    final client = MockClient((request) async {
      expect(request.url.path, '/predict-weight');
      expect(request.headers['content-type'], contains('multipart/form-data'));
      return http.Response(
          jsonEncode({
            'estimated_weight_kg': 350,
            'prediction_spread_kg': 5,
            'num_valid_images': 1
          }),
          200);
    });
    expect(
        (await ApiService.predictWeight([image],
            client: client))['estimated_weight_kg'],
        350);
    client.close();
    final invalid = MockClient(
        (_) async => http.Response('{"estimated_weight_kg":-1}', 200));
    await expectLater(ApiService.predictWeight([image], client: invalid),
        throwsFormatException);
    invalid.close();
  });
}
