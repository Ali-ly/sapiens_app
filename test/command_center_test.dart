import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/app.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/farm_command_center.dart';
import 'package:sapita_app/models/farm_snapshot.dart';
import 'package:sapita_app/models/feed_plan.dart';
import 'package:sapita_app/screens/cattle/cattle_estimate_result_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_list_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_profile_screen.dart';
import 'package:sapita_app/screens/feed/feed_calculator_screen.dart';
import 'package:sapita_app/screens/home/command_center_screen.dart';
import 'package:sapita_app/screens/home/widgets/farm_action_tile.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/test_app.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24, 12);
  Cattle animal(String id, {int daysAgo = 0, double? weight = 350}) => Cattle(
        id: id,
        nameOrId: id,
        gender: 'Jantan',
        ageMonths: 18,
        estimatedWeight: weight,
        history: weight == null
            ? []
            : [
                WeightRecord(
                  weightKg: weight,
                  date: now.subtract(Duration(days: daysAgo)),
                  source: 'manual',
                )
              ],
      );
  FeedPlan plan(Cattle cattle, {String id = 'plan', DateTime? date}) =>
      FeedPlan(
        id: id,
        cattleId: cattle.id,
        cattleName: cattle.nameOrId,
        weightKg: cattle.estimatedWeight!,
        ageMonths: cattle.ageMonths,
        gender: cattle.gender,
        bodyCondition: 'Sedang',
        target: 'penggemukan',
        availableFeeds: ['rumput'],
        createdAt: date ?? now,
        weightDate: cattle.history.last.date,
        portions: const [FeedPortion(key: 'rumput', asFedKg: 22)],
      );

  test(
    'Empty farms expose no synthetic actions, activity or feed coverage',
    () {
      final center = FarmCommandCenter.fromSnapshot(FarmSnapshot(), now);
      expect(center.actions, isEmpty);
      expect(center.activity, isEmpty);
      expect(center.feedCoverage, 0);
      expect(center.dailyFreshKg, 0);
    },
  );

  test(
    'Each animal has one next step ordered by weight prerequisites then feed',
    () {
      final active = animal('active');
      final stale = animal('stale');
      final overdue = animal('overdue', daysAgo: 7);
      final snapshot = FarmSnapshot(
        cattle: [
          active,
          animal('fresh'),
          stale,
          overdue,
          animal('new', weight: null)
        ],
        feedPlans: [
          plan(active),
          plan(stale.copyWith(ageMonths: 17), id: 'old'),
          plan(overdue, id: 'overdue-plan')
        ],
      );
      final center = FarmCommandCenter.fromSnapshot(snapshot, now);
      expect(
        center.actions.map((a) => a.kind),
        [
          FarmActionKind.recordWeight,
          FarmActionKind.checkWeight,
          FarmActionKind.calculateFeed,
          FarmActionKind.refreshFeed
        ],
      );
      expect(
        center.actions.map((a) => a.cattle.id).toSet().length,
        center.actions.length,
      );
      expect(center.unweighedCount, 1);
      expect(center.dueCount, 1);
      expect(center.readyCount, 1);
      expect(center.feedAttentionCount, 4);
      expect(center.dailyFreshKg, 22);
      expect(center.feedCoverage, .2);
      expect(() => center.actions.clear(), throwsUnsupportedError);
      expect(() => center.dailyFeedTotals.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Overdue work is oldest first and ready plans match the existing store',
    () async {
      final a = animal('A', daysAgo: 8), b = animal('B', daysAgo: 10);
      final fresh = animal('C');
      final store = FarmStore(
        now: () => now,
        read: () async => null,
        write: (_) async {},
      );
      await store.load();
      for (final value in [a, b, fresh]) {
        await store.saveCattle(value);
      }
      await store.savePlan(plan(a));
      await store.savePlan(plan(fresh, id: 'fresh'));
      expect(store.commandCenter.actions.map((a) => a.cattle.id), ['B', 'A']);
      expect(
        store.commandCenter.readyCount,
        store.cattle.where(store.planReady).length,
      );
      expect(store.commandCenter.dailyFeedTotals, store.dailyFeedTotals);
      store.dispose();
    },
  );

  test(
    'Activity merges recorded weights and plans, newest first, without future records',
    () {
      final a = animal('A', daysAgo: 1);
      final b = animal('B', daysAgo: -1);
      final center = FarmCommandCenter.fromSnapshot(
        FarmSnapshot(
          cattle: [a, b],
          feedPlans: [
            plan(a),
            plan(b, id: 'future', date: now.add(const Duration(days: 1)))
          ],
        ),
        now,
      );
      expect(center.activity.length, 2);
      expect(center.activity.first.kind, FarmActivityKind.feedPlan);
      expect(center.activity.last.kind, FarmActivityKind.weight);
    },
  );

  test(
    'Latest plan ties use the same last-saved rule as feed totals',
    () {
      final c = animal('A');
      final center = FarmCommandCenter.fromSnapshot(
        FarmSnapshot(
          cattle: [c],
          feedPlans: [plan(c), plan(c.copyWith(ageMonths: 17), id: 'last')],
        ),
        now,
      );
      expect(center.readyCount, 0);
      expect(center.dailyFeedTotals, isEmpty);
      expect(center.actions.single.kind, FarmActionKind.refreshFeed);
    },
  );

  test(
    'Completing prerequisites updates the queue and survives a backup reload',
    () async {
      String? disk;
      final store = FarmStore(
        now: () => now,
        read: () async => disk,
        write: (value) async {
          disk = value;
        },
      );
      await store.load();
      final c = await store.saveCattle(animal('A', weight: null));
      expect(
        store.commandCenter.actions.single.kind,
        FarmActionKind.recordWeight,
      );
      final weighed =
          await store.recordWeight(c.id, weightKg: 350, source: 'manual');
      expect(
        store.commandCenter.actions.single.kind,
        FarmActionKind.calculateFeed,
      );
      await store.savePlan(plan(weighed));
      expect(store.commandCenter.actions, isEmpty);
      expect(store.exportData()['schemaVersion'], 4);
      final backup = jsonEncode(store.exportData());
      final reloaded = FarmStore(
        now: () => now,
        read: () async => backup,
        write: (_) async {},
      );
      await reloaded.load();
      expect(reloaded.commandCenter.readyCount, 1);
      expect(reloaded.commandCenter.dailyFreshKg, 22);
      store.dispose();
      reloaded.dispose();
    },
  );

  testWidgets(
    'Dashboard filters switch the existing tab and system back returns to summary',
    (tester) async {
      final store = FarmStore(
        now: () => now,
        read: () async => null,
        write: (_) async {},
      );
      await store.load();
      await store.saveCattle(animal('Fresh'));
      await store.saveCattle(animal('Due', daysAgo: 8));
      await tester.pumpWidget(SapiensApp(store: store));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Perlu catatan bobot'), 200,
          scrollable: find
              .byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down)
              .last);
      await tester.ensureVisible(find.text('Perlu catatan bobot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perlu catatan bobot'));
      await tester.pumpAndSettle();
      expect(find.byType(CattleListScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.text('1 sapi ditemukan'), 150,
          scrollable: find
              .byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down)
              .last);
      expect(find.text('1 sapi ditemukan'), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
        isFalse,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CommandCenterScreen), findsOneWidget);
      await tester.tap(find.text('Ternak').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('1 sapi ditemukan'), 150,
          scrollable: find
              .byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down)
              .last);
      expect(find.text('1 sapi ditemukan'), findsOneWidget);
      await tester.tap(find.text('Ringkasan').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Profil individual'), -200,
          scrollable: find
              .byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down)
              .last);
      await tester.ensureVisible(find.text('Profil individual'));
      await tester.tap(find.text('Profil individual').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('2 sapi ditemukan'), 150,
          scrollable: find
              .byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down)
              .last);
      expect(find.text('2 sapi ditemukan'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'A weight priority opens the weight section directly',
    (tester) async {
      final c = animal('New', weight: null);
      final store = FarmStore(
        now: () => now,
        read: () async => null,
        write: (_) async {},
      );
      await store.load();
      await store.saveCattle(c);
      await tester.pumpWidget(
        buildTestApp(
          store: store,
          home: Scaffold(
            body: FarmActionTile(
              action: FarmAction(cattle: c, kind: FarmActionKind.recordWeight),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('farm-action-New')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CattleProfileScreen>(find.byType(CattleProfileScreen))
            .initialSection,
        CattleProfileSection.weight,
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'Calculator weight edits use a dialog without pushing another cattle profile',
    (tester) async {
      final store = FarmStore(
        now: () => now,
        read: () async => null,
        write: (_) async {},
      );
      await store.load();
      final c = await store.saveCattle(animal('New', weight: null));
      await tester.pumpWidget(
        buildTestApp(
          store: store,
          home: FeedCalculatorScreen(cattleId: c.id),
        ),
      );
      await tester.ensureVisible(find.text('Catat bobot'));
      await tester.tap(find.text('Catat bobot'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.byType(CattleProfileScreen, skipOffstage: false),
        findsNothing,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bobot (kg)'),
        '350',
      );
      await tester.tap(find.text('Simpan bobot'));
      await tester.pumpAndSettle();
      expect(store.byId(c.id)!.estimatedWeight, 350);
      expect(find.byType(FeedCalculatorScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'Saving an AI review replaces that completed step with the calculator',
    (tester) async {
      final store = FarmStore(
        now: () => now,
        read: () async => null,
        write: (_) async {},
      );
      await store.load();
      final c = await store.saveCattle(animal('A'));
      await tester.pumpWidget(
        buildTestApp(
          store: store,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Review'),
                onPressed: () => Navigator.push<Cattle>(
                  context,
                  MaterialPageRoute<Cattle>(
                      builder: (_) => CattleEstimateResultScreen(
                            draft: c.copyWith(estimatedWeight: 360),
                          )),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Simpan & hitung pakan'),
        200,
        scrollable: find
            .byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down)
            .last,
      );
      await tester.tap(find.text('Simpan & hitung pakan'));
      await tester.pumpAndSettle();
      expect(store.byId(c.id)!.estimatedWeight, 360);
      expect(find.byType(FeedCalculatorScreen), findsOneWidget);
      expect(
        find.byType(CattleEstimateResultScreen, skipOffstage: false),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Review'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'System back after saving feed finishes the calculator instead of reopening it',
    (tester) async {
      final store = FarmStore(
          now: () => now, read: () async => null, write: (_) async {});
      await store.load();
      final c = await store.saveCattle(animal('A'));
      await tester.pumpWidget(
        buildTestApp(
          store: store,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Calculate'),
                onPressed: () => Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                      builder: (_) => FeedCalculatorScreen(
                            cattleId: c.id,
                            calculate: (
                                    {required cattle,
                                    required target,
                                    required condition,
                                    required availableFeeds}) async =>
                                plan(cattle),
                          )),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Lihat rekomendasi pakan'), 200,
          scrollable: find
              .byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down)
              .last);
      await tester.tap(find.text('Lihat rekomendasi pakan'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('Gunakan & simpan rencana'), 200,
          scrollable: find
              .byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down)
              .last);
      await tester.tap(find.text('Gunakan & simpan rencana'));
      await tester.pumpAndSettle();
      expect(store.feedPlans, hasLength(1));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Calculate'), findsOneWidget);
      expect(
          find.byType(FeedCalculatorScreen, skipOffstage: false), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'Command Center and queue render at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = FarmStore(
          now: () => now,
          read: () async => null,
          write: (_) async {},
        );
        await store.load();
        await store.addExamples();
        await tester.pumpWidget(SapiensApp(store: store));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Aktivitas terbaru'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Lihat semua'),
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Lihat semua').first),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lihat semua').first);
        await tester.pumpAndSettle();
        expect(find.text('Langkah berikutnya.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
}
