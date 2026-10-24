import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/app.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/feed_plan.dart';
import 'package:sapita_app/screens/cattle/add_cattle_screen.dart';
import 'package:sapita_app/services/feed_response_mapper.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/feed_fixture.dart';
import 'helpers/test_app.dart';

void main() {
  late FarmStore store;
  String? memory;
  bool failWrites = false;
  setUp(
    () async {
      memory = null;
      failWrites = false;
      store = FarmStore(
        read: () async => memory,
        write: (s) async {
          if (failWrites) {
            throw Exception('disk full');
          }
          memory = s;
        },
      );
      await store.load();
    },
  );
  Future<Cattle> realCattle() => store.saveCattle(
        Cattle(
          nameOrId: 'Milik saya',
          gender: 'Jantan',
          ageMonths: 18,
          estimatedWeight: 350,
          history: [
            WeightRecord(weightKg: 350, date: DateTime.now(), source: 'manual')
          ],
        ),
      );
  FeedPlan planFor(Cattle c) => FeedResponseMapper.parse(
        cattle: c,
        target: 'penggemukan',
        condition: 'Sedang',
        feeds: ['rumput', 'jerami', 'dedak'],
        data: readFeedResponse(),
      );
  test(
    'Identity edit preserves the latest weight and history',
    () async {
      final original = await realCattle();
      await store.saveCattle(
        original.copyWith(
          estimatedWeight: 360,
          history: [
            ...original.history,
            WeightRecord(weightKg: 360, date: DateTime.now(), source: 'manual')
          ],
        ),
      );
      final updated = await store.updateIdentity(
        original.id,
        name: 'Nama baru',
        gender: 'Jantan',
        ageMonths: 18,
        notes: 'Catatan',
      );
      expect(updated.nameOrId, 'Nama baru');
      expect(updated.estimatedWeight, 360);
      expect(updated.history.length, 2);
    },
  );
  test(
    'Duplicate identity edits fail without replacing data',
    () async {
      final c = await realCattle();
      await store.saveCattle(
        Cattle(nameOrId: 'Sudah dipakai', gender: 'Betina', ageMonths: 20),
      );
      await expectLater(
        store.updateIdentity(
          c.id,
          name: 'SUDAH DIPAKAI',
          gender: 'Jantan',
          ageMonths: 18,
          notes: '',
        ),
        throwsStateError,
      );
      expect(store.byId(c.id)!.nameOrId, 'Milik saya');
    },
  );
  test(
    'Deleted cattle cannot be recreated by a stale edit form',
    () async {
      final c = await realCattle();
      await store.remove(c.id);
      await expectLater(
        store.updateIdentity(
          c.id,
          name: 'Nama',
          gender: 'Jantan',
          ageMonths: 18,
          notes: '',
        ),
        throwsStateError,
      );
      expect(store.cattle, isEmpty);
    },
  );
  test(
    'Removing examples preserves real cattle and their feed plans',
    () async {
      await store.addExamples();
      final real = await realCattle();
      await store.savePlan(planFor(real));
      final demo = store.cattle.first;
      final demoData = readFeedResponse();
      demoData['weight_kg'] = demo.estimatedWeight;
      await store.savePlan(
        FeedResponseMapper.parse(
          cattle: demo,
          target: 'penggemukan',
          condition: 'Sedang',
          feeds: ['rumput', 'jerami', 'dedak'],
          data: demoData,
        ),
      );
      await store.removeExamples();
      expect(store.cattle.single.id, real.id);
      expect(store.feedPlans.single.cattleId, real.id);
      expect(store.demo, isFalse);
    },
  );
  test(
    'A failed example cleanup leaves the complete data intact',
    () async {
      await store.addExamples();
      await realCattle();
      failWrites = true;
      await expectLater(store.removeExamples(), throwsException);
      expect(store.cattle.length, 6);
      expect(store.demo, isTrue);
    },
  );
  test(
    'Failed reload does not partially replace a previously loaded farm',
    () async {
      final c = await realCattle();
      final before = store.farmer;
      memory = jsonEncode(
        {
          'farmer': 'Should not apply',
          'farm': 'Broken',
          'reminderDays': 7,
          'cattle': [
            {'id': 'bad'}
          ]
        },
      );
      await store.load();
      expect(store.error, isNotNull);
      expect(store.farmer, before);
      expect(store.cattle.single.id, c.id);
    },
  );
  testWidgets(
    'SAPIENS brand is displayed for a new farm',
    (tester) async {
      await tester.pumpWidget(SapiensApp(store: store));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'SAPIENS',
      );
      expect(find.text('Selamat datang di SAPIENS.'), findsOneWidget);
    },
  );
  testWidgets(
    'Unsaved cattle forms require an explicit discard decision',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          store: store,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const AddCattleScreen()),
                ),
                child: const Text('Buka formulir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka formulir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama / ID sapi'),
        'Belum disimpan',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Perubahan belum disimpan'), findsOneWidget);
      await tester.tap(find.text('Lanjut mengisi'));
      await tester.pumpAndSettle();
      expect(find.text('Belum disimpan'), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abaikan perubahan'));
      await tester.pumpAndSettle();
      expect(find.text('Buka formulir'), findsOneWidget);
      expect(store.cattle, isEmpty);
    },
  );
}
