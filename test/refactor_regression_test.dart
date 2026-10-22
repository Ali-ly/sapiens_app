import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapita_app/app.dart';
import 'package:sapita_app/data/farm_backup_codec.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/selected_image.dart';
import 'package:sapita_app/services/feed_response_mapper.dart';
import 'package:sapita_app/services/feed_service.dart';
import 'package:sapita_app/state/farm_scope.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/feed_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23, 12);
  late FarmStore store;
  String? memory;
  setUp(
    () async {
      memory = null;
      store = FarmStore(
        now: () => now,
        read: () async => memory,
        write: (value) async {
          memory = value;
        },
      );
      await store.load();
    },
  );
  Future<Cattle> addCattle() => store.saveCattle(
        Cattle(
          nameOrId: 'Budi',
          gender: 'Jantan',
          ageMonths: 18,
          estimatedWeight: 350,
          history: [
            WeightRecord(
              weightKg: 350,
              date: now.subtract(const Duration(days: 1)),
              source: 'manual',
            )
          ],
        ),
      );

  test(
    'Cattle copies its history and the public store collections are read-only',
    () async {
      final history = [WeightRecord(weightKg: 350, date: now)];
      final animal = Cattle(
        nameOrId: 'Budi',
        gender: 'Jantan',
        ageMonths: 18,
        estimatedWeight: 350,
        history: history,
      );
      history.clear();
      expect(animal.history.length, 1);
      expect(() => animal.history.clear(), throwsUnsupportedError);
      await store.saveCattle(animal);
      expect(() => store.cattle.clear(), throwsUnsupportedError);
      expect(() => store.feedPlans.clear(), throwsUnsupportedError);
      expect(
        () => store.dailyFeedTotals['rumput'] = 100,
        throwsUnsupportedError,
      );
    },
  );
  test(
    'Selected image snapshots cannot be changed through their byte buffer',
    () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final image = SelectedImage(
        file: XFile.fromData(bytes, name: 'cow.jpg'),
        bytes: bytes,
      );
      bytes[0] = 99;
      expect(image.bytes.first, 1);
      expect(() => image.bytes[0] = 42, throwsUnsupportedError);
    },
  );
  test(
    'Concurrent weight checks retain both records in write order',
    () async {
      final animal = await addCattle();
      await Future.wait(
        [
          store.recordWeight(animal.id, weightKg: 360, source: 'manual'),
          store.recordWeight(animal.id, weightKg: 370, source: 'manual'),
        ],
      );
      expect(
        store.cattle.single.history.map((record) => record.weightKg),
        [350, 360, 370],
      );
      expect(store.cattle.single.estimatedWeight, 370);
    },
  );
  test(
    'A stale AI result is rejected without blocking the next manual write',
    () async {
      final animal = await addCattle();
      await store.recordWeight(animal.id, weightKg: 360, source: 'manual');
      await expectLater(
        store.recordWeight(
          animal.id,
          weightKg: 355,
          source: 'ai',
          expectedHistoryLength: 1,
        ),
        throwsStateError,
      );
      await store.recordWeight(animal.id, weightKg: 370, source: 'manual');
      expect(store.cattle.single.history.length, 3);
      expect(store.cattle.single.estimatedWeight, 370);
    },
  );
  test(
    'Weight recording uses the latest identity rather than a stale screen snapshot',
    () async {
      final animal = await addCattle();
      await store.updateIdentity(
        animal.id,
        name: 'Nama baru',
        gender: 'Jantan',
        ageMonths: 20,
        notes: 'Dipindah kandang',
      );
      final updated =
          await store.recordWeight(animal.id, weightKg: 360, source: 'manual');
      expect(updated.nameOrId, 'Nama baru');
      expect(updated.ageMonths, 20);
      expect(updated.notes, 'Dipindah kandang');
    },
  );
  test(
    'Disk reads and imports both reject mismatched history and latest weight',
    () async {
      final animal = await addCattle();
      final data = store.exportData();
      final encoded = (data['cattle'] as List).single as Map<String, dynamic>;
      encoded['weight'] = 999;
      final invalid = jsonEncode(data);
      expect(() => FarmBackupCodec.decode(invalid), throwsFormatException);
      memory = invalid;
      await store.load();
      expect(store.error, isNotNull);
      expect(store.cattle.single.id, animal.id);
      expect(store.cattle.single.estimatedWeight, 350);
    },
  );
  test(
    'A valid backup can recover a store after an unreadable disk snapshot',
    () async {
      await addCattle();
      final backup = jsonEncode(store.exportData());
      memory = 'invalid JSON';
      await store.load();
      expect(store.error, isNotNull);
      await store.restoreBackup(backup);
      expect(store.error, isNull);
      expect(store.cattle.single.nameOrId, 'Budi');
    },
  );
  test(
    'The injected clock defines the seven-day activity boundary',
    () async {
      await store.saveCattle(
        Cattle(
          nameOrId: 'Budi',
          gender: 'Jantan',
          ageMonths: 18,
          estimatedWeight: 350,
          history: [
            WeightRecord(
              weightKg: 340,
              date: now.subtract(const Duration(days: 7)),
            ),
            WeightRecord(
              weightKg: 345,
              date: now.subtract(const Duration(days: 6)),
            ),
            WeightRecord(
              weightKg: 350,
              date: now.add(const Duration(hours: 1)),
            ),
          ],
        ),
      );
      expect(store.checksThisWeek, 1);
    },
  );
  test(
    'The feed service returns an immutable plan instead of a raw response map',
    () async {
      final animal = await addCattle();
      final client = MockClient(
        (_) async => http.Response(jsonEncode(readFeedResponse()), 200),
      );
      final plan = await FeedService.calculatePlan(
        cattle: animal,
        target: 'penggemukan',
        condition: 'Sedang',
        availableFeeds: ['rumput', 'jerami', 'dedak'],
        client: client,
      );
      expect(plan.totalFreshKg, closeTo(27.3, .001));
      expect(plan.matches(animal), isTrue);
      expect(() => plan.portions.clear(), throwsUnsupportedError);
      expect(() => plan.notes.clear(), throwsUnsupportedError);
      client.close();
    },
  );
  test(
    'Startup writes wait for persisted data before changing preferences',
    () async {
      await addCattle();
      final disk = Completer<String?>();
      final starting = FarmStore(read: () => disk.future, write: (_) async {});
      final change = starting.settings('Ali', 'Kandang Ali', 14);
      disk.complete(memory);
      await change;
      expect(starting.cattle.single.nameOrId, 'Budi');
      expect(starting.farmer, 'Ali');
      starting.dispose();
    },
  );

  test(
    'Zero feed plans are rejected during backup import without replacing data',
    () async {
      final animal = await addCattle();
      final plan = FeedResponseMapper.parse(
        cattle: animal,
        target: 'penggemukan',
        condition: 'Sedang',
        feeds: ['rumput', 'jerami', 'dedak'],
        data: readFeedResponse(),
      );
      await store.savePlan(plan);
      final data = store.exportData();
      final encoded =
          (data['feedPlans'] as List).single as Map<String, dynamic>;
      for (final portion in encoded['portions'] as List) {
        (portion as Map<String, dynamic>)['asFedKg'] = 0;
      }
      await expectLater(
        store.restoreBackup(jsonEncode(data)),
        throwsFormatException,
      );
      expect(store.feedPlans.single.totalFreshKg, closeTo(27.3, .001));
    },
  );

  testWidgets(
    'Independent app trees receive their own store',
    (tester) async {
      final other = FarmStore(read: () async => null, write: (_) async {});
      await other.load();
      await store.settings('Ali', 'Kandang Ali', 7);
      await other.settings('Dewi', 'Kandang Dewi', 14);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              FarmScope(
                store: store,
                child: Builder(
                  builder: (context) => Text(FarmScope.read(context).farmer),
                ),
              ),
              FarmScope(
                store: other,
                child: Builder(
                  builder: (context) => Text(FarmScope.read(context).farmer),
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Dewi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      other.dispose();
    },
  );
  testWidgets(
    'App disposal does not dispose a caller-owned store',
    (tester) async {
      var notifications = 0;
      store.addListener(() => notifications++);
      await tester.pumpWidget(SapitaApp(store: store));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await store.settings('Ali', 'Kandang Ali', 7);
      expect(notifications, 1);
    },
  );
}
