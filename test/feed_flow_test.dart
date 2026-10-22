import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cattle_app/app.dart';
import 'package:cattle_app/core/theme/app_theme.dart';
import 'package:cattle_app/models/cattle_draft.dart';
import 'package:cattle_app/state/farm_store.dart';
import 'package:cattle_app/screens/feed/feed_calculator_screen.dart';

void main() {
  late FarmStore store;
  setUp(() async {
    store = FarmStore(read: () async => null, write: (_) async {});
    FarmStore.instance = store;
    await store.load();
  });
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 260,
        scrollable: find.byType(Scrollable).last, maxScrolls: 40);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Weight → feed request → result → saved cattle plan',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await store.save(CattleDraft(
        nameOrId: 'B001 - Budi',
        gender: 'Jantan',
        ageMonths: 18,
        estimatedWeight: 350,
        history: [
          WeightRecord(weightKg: 350, date: DateTime.now(), source: 'manual')
        ]));
    Map<String, Object>? sent;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: FeedCalculatorScreen(
            cattleId: c.id,
            calculate: (
                {required weight,
                required target,
                required availableFeeds}) async {
              sent = {
                'weight': weight,
                'target': target,
                'available_feeds': availableFeeds
              };
              return Map<String, dynamic>.from(jsonDecode(
                  File('test/fixtures/feed_response.json').readAsStringSync()));
            })));
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
  });
  testWidgets(
      'Unsupported dedak-only selection shows validation without API request',
      (tester) async {
    final c = await store.save(CattleDraft(
        nameOrId: 'Budi',
        gender: 'Jantan',
        ageMonths: 18,
        estimatedWeight: 350,
        history: [WeightRecord(weightKg: 350, date: DateTime.now())]));
    bool called = false;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: FeedCalculatorScreen(
            cattleId: c.id,
            calculate: (
                {required weight,
                required target,
                required availableFeeds}) async {
              called = true;
              return {};
            })));
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
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('All four main tabs build without overflow at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await store.addExamples();
      await tester.pumpWidget(const SapitaApp());
      await tester.pumpAndSettle();
      for (final label in ['Sapi', 'Pakan', 'Profil', 'Beranda']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
