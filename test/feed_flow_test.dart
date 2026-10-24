import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/app.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/screens/feed/feed_calculator_screen.dart';
import 'package:sapita_app/services/feed_response_mapper.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/feed_fixture.dart';
import 'helpers/test_app.dart';

void main() {
  late FarmStore store;
  setUp(
    () async {
      store = FarmStore(read: () async => null, write: (_) async {});
      await store.load();
    },
  );
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      260,
      scrollable: find
          .byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down)
          .last,
      maxScrolls: 40,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Weight → feed request → result → saved cattle plan',
    (tester) async {
      store = FarmStore(read: () async => null, write: (_) async {});
      await store.load();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await store.saveCattle(
        Cattle(
          nameOrId: 'B001 - Budi',
          gender: 'Jantan',
          ageMonths: 18,
          estimatedWeight: 350,
          history: [
            WeightRecord(weightKg: 350, date: DateTime.now(), source: 'manual')
          ],
        ),
      );
      Map<String, Object>? sent;
      await tester.pumpWidget(
        buildTestApp(
          store: store,
          home: FeedCalculatorScreen(
            cattleId: c.id,
            calculate: (
                {required cattle,
                required condition,
                required target,
                required availableFeeds}) async {
              sent = {
                'weight': cattle.estimatedWeight!,
                'target': target,
                'available_feeds': availableFeeds
              };
              return FeedResponseMapper.parse(
                cattle: cattle,
                target: target,
                condition: condition,
                feeds: availableFeeds,
                data: readFeedResponse(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Penggemukan'));
      await tester.tap(find.text('Penggemukan'));
      await tester.pumpAndSettle();
      for (final text in ['Jerami padi', 'Dedak padi']) {
        final item = find.widgetWithText(SwitchListTile, text);
        await reveal(tester, item);
        await tester.tap(item);
        await tester.pumpAndSettle();
      }
      await reveal(tester, find.text('Lihat rekomendasi pakan'));
      await tester.tap(find.text('Lihat rekomendasi pakan'));
      await tester.pumpAndSettle();
      expect(sent!['weight'], 350);
      expect(sent!['target'], 'penggemukan');
      expect(sent!['available_feeds'], ['rumput', 'jerami', 'dedak']);
      expect(find.text('27,3 kg'), findsOneWidget);
      await reveal(tester, find.text('Gunakan & simpan rencana'));
      await tester.tap(find.text('Gunakan & simpan rencana'));
      await tester.pumpAndSettle();
      expect(store.feedPlans.length, 1);
      expect(store.planReady(store.cattle.single), isTrue);
      expect(store.dailyFeedTotals['rumput'], 22);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Unsupported dedak-only selection shows validation without API request',
    (tester) async {
      store = FarmStore(read: () async => null, write: (_) async {});
      await store.load();
      final c = await store.saveCattle(
        Cattle(
          nameOrId: 'Budi',
          gender: 'Jantan',
          ageMonths: 18,
          estimatedWeight: 350,
          history: [WeightRecord(weightKg: 350, date: DateTime.now())],
        ),
      );
      bool called = false;
      await tester.pumpWidget(
        buildTestApp(
          store: store,
          home: FeedCalculatorScreen(
            cattleId: c.id,
            calculate: (
                {required cattle,
                required condition,
                required target,
                required availableFeeds}) async {
              called = true;
              throw StateError('Invalid input should never call the service.');
            },
          ),
        ),
      );
      for (final text in ['Rumput hijauan', 'Dedak padi']) {
        final item = find.widgetWithText(SwitchListTile, text);
        await reveal(tester, item);
        await tester.tap(item);
        await tester.pumpAndSettle();
      }
      await reveal(tester, find.text('Lihat rekomendasi pakan'));
      await tester.tap(find.text('Lihat rekomendasi pakan'));
      await tester.pumpAndSettle();
      expect(called, isFalse);
      expect(find.textContaining('Tambahkan rumput hijauan'), findsOneWidget);
      expect(store.feedPlans, isEmpty);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'All four main tabs build without overflow at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        store = FarmStore(read: () async => null, write: (_) async {});
        await store.load();
        await store.addExamples();
        await tester.pumpWidget(SapiensApp(store: store));
        await tester.pumpAndSettle();
        for (final label in ['Ternak', 'Pakan', 'Profil', 'Ringkasan']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
