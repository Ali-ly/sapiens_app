import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sapita_app/app.dart';
import 'package:sapita_app/core/constants/app_colors.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/screens/cattle/add_cattle_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_list_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_profile_screen.dart';
import 'package:sapita_app/screens/feed/feed_hub_screen.dart';
import 'package:sapita_app/screens/feed/feed_shopping_screen.dart';
import 'package:sapita_app/screens/feed/individual_feed_entry_screen.dart';
import 'package:sapita_app/screens/groups/group_detail_screen.dart';
import 'package:sapita_app/screens/groups/group_feed_screen.dart';
import 'package:sapita_app/screens/groups/group_list_screen.dart';
import 'package:sapita_app/services/group_feed_service.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/feed_fixture.dart';
import 'helpers/legacy_feed_plan_fixture.dart';
import 'helpers/test_app.dart';

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200,
      scrollable: find
          .byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down)
          .last,
      maxScrolls: 40);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final source in ['manual', 'ai']) {
    testWidgets(
        'Feed button is disabled without weight and immediately enables after $source measurement',
        (tester) async {
      final store = FarmStore(read: () async => null, write: (_) async {});
      await store.load();
      final c = await store.saveCattle(
          Cattle(nameOrId: 'Budi', gender: 'Jantan', ageMonths: 18));
      await tester.pumpWidget(buildTestApp(
          store: store,
          home: CattleProfileScreen(
              cattle: c, initialSection: CattleProfileSection.feed)));
      final button = find.byKey(const ValueKey('cattle-feed-button'));
      await reveal(tester, button);
      final disabled = tester.widget<FilledButton>(button);
      expect(disabled.onPressed, isNull);
      expect(disabled.style!.backgroundColor!.resolve({WidgetState.disabled}),
          AppColors.divider);
      expect(
          find.text(
              'Catat bobot manual atau gunakan estimasi foto terlebih dahulu.'),
          findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(IndividualFeedEntryScreen), findsNothing);
      await store.recordWeight(c.id, weightKg: 350, source: source);
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(IndividualFeedEntryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }

  testWidgets(
      'A farmer creates and edits a bulk group with no individual profiles',
      (tester) async {
    final store = FarmStore(read: () async => null, write: (_) async {});
    await store.load();
    await tester
        .pumpWidget(buildTestApp(store: store, home: const GroupListScreen()));
    await tester.tap(find.byTooltip('Buat kelompok/kandang'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama kelompok/kandang'),
        'Kandang Utara');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah sapi'), '20');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Bobot rata-rata (kg)'), '350');
    await tester.ensureVisible(find.text('Simpan kelompok'));
    await tester.tap(find.text('Simpan kelompok'));
    await tester.pumpAndSettle();
    expect(store.cattle, isEmpty);
    expect(store.groups.single.headCount, 20);
    expect(find.byType(GroupDetailScreen), findsOneWidget);
    expect(find.text('20 ekor'), findsOneWidget);
    expect(find.text('Anggota saat ini'), findsNothing);
    await tester.tap(find.byTooltip('Edit data kelompok'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah sapi'), '30');
    await tester.ensureVisible(find.text('Simpan kelompok'));
    await tester.tap(find.text('Simpan kelompok'));
    await tester.pumpAndSettle();
    expect(store.groups.single.history, hasLength(2));
    expect(store.groups.single.headCount, 30);
    expect(store.groups.single.history.first.headCount, 20);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
      'Bulk feed can be calculated and saved without a single individual cow',
      (tester) async {
    final store = FarmStore(read: () async => null, write: (_) async {});
    await store.load();
    final group = await store.createGroup('Kandang A',
        headCount: 10, averageWeightKg: 350, target: 'penggemukan');
    final client = MockClient(
        (_) async => http.Response(jsonEncode(readFeedResponse()), 200));
    await tester.pumpWidget(buildTestApp(
        store: store,
        home: GroupFeedScreen(
            groupId: group.id,
            calculate: ({required group, required availableFeeds}) =>
                GroupFeedService.calculate(
                    group: group,
                    availableFeeds: availableFeeds,
                    client: client))));
    for (final label in ['Jerami padi', 'Dedak padi']) {
      await reveal(tester, find.widgetWithText(CheckboxListTile, label));
      await tester.tap(find.widgetWithText(CheckboxListTile, label));
      await tester.pumpAndSettle();
    }
    await reveal(tester, find.text('Hitung pakan kelompok'));
    await tester.tap(find.text('Hitung pakan kelompok'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('273,0 kg / hari'));
    expect(find.text('273,0 kg / hari'), findsOneWidget);
    await reveal(tester, find.text('Simpan rencana kelompok'));
    await tester.tap(find.text('Simpan rencana kelompok'));
    await tester.pumpAndSettle();
    expect(store.groupFeedPlans, hasLength(1));
    expect(store.groupDailyFeedTotals['rumput'], 220);
    expect(store.cattle, isEmpty);
    await store.updateGroup(group.id,
        name: group.name,
        headCount: 20,
        averageWeightKg: 350,
        target: group.target,
        notes: '');
    await tester.pumpAndSettle();
    expect(store.groupDailyFeedTotals, isEmpty);
    expect(store.groupPlanReady(store.groups.single), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(buildTestApp(
        store: store, home: const FeedShoppingScreen(initialGroupScope: true)));
    await tester.pumpAndSettle();
    expect(find.text('0 kelompok dengan rencana terkini'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
    store.dispose();
  });

  for (final hasGroups in [false, true]) {
    testWidgets('Individual flow stays primary with groups=$hasGroups',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FarmStore(read: () async => null, write: (_) async {});
      await store.load();
      await store.configureProductionSystems(FarmProductionSystems.beef);
      if (hasGroups) {
        await store.createGroup('Kandang besar',
            headCount: 100, averageWeightKg: 350);
      }
      await store.configureProductionSystems(FarmProductionSystems.beef);
      await tester.pumpWidget(SapiensApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('Mulai dari sapi pertamamu.'), findsOneWidget);
      expect(find.text('Livestock Management'), findsNothing);
      await reveal(tester, find.text('Tambah sapi pertama'));
      await tester.tap(find.text('Tambah sapi pertama'));
      await tester.pumpAndSettle();
      expect(find.byType(AddCattleScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ternak').last);
      await tester.pumpAndSettle();
      expect(find.byType(CattleListScreen), findsOneWidget);
      expect(find.byType(GroupListScreen), findsNothing);
      await tester.enterText(find.byType(TextField), 'Budi');
      await reveal(tester, find.text('Kelompok/kandang (opsional)'));
      await tester.tap(find.text('Kelompok/kandang (opsional)'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupListScreen), findsOneWidget);
      if (hasGroups) {
        await reveal(tester, find.text('Rekap pakan kelompok'));
        await tester.tap(find.text('Rekap pakan kelompok'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Kelompok'))
                .selected,
            isTrue);
        await tester.tap(find.byTooltip('Kembali'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.byType(CattleListScreen), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Budi');
      expect(store.groups.length, hasGroups ? 1 : 0);
      await tester.tap(find.text('Pakan').last);
      await tester.pumpAndSettle();
      expect(find.byType(FeedHubScreen), findsOneWidget);
      await reveal(tester, find.text('Tambahkan sapi pertama'));
      await tester.tap(find.text('Tambahkan sapi pertama'));
      await tester.pumpAndSettle();
      expect(find.byType(AddCattleScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }

  testWidgets(
      'Home with cattle opens the individual list through its primary action',
      (tester) async {
    final store = FarmStore(read: () async => null, write: (_) async {});
    await store.load();
    await store
        .saveCattle(Cattle(nameOrId: 'Budi', gender: 'Jantan', ageMonths: 18));
    await store.createGroup('Kandang besar',
        headCount: 100, averageWeightKg: 350);
    await store.configureProductionSystems(FarmProductionSystems.beef);
    await tester.pumpWidget(SapiensApp(store: store));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Lihat sapimu'));
    await tester.tap(find.text('Lihat sapimu'));
    await tester.pumpAndSettle();
    expect(find.byType(CattleListScreen), findsOneWidget);
    expect(find.byType(GroupListScreen), findsNothing);
    expect(store.groups.single.headCount, 100);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('Shopping scope never combines bulk and individual rations',
      (tester) async {
    final store = FarmStore(read: () async => null, write: (_) async {});
    await store.load();
    final group = await store.createGroup('Kandang A',
        headCount: 10, averageWeightKg: 350, target: 'penggemukan');
    final client = MockClient(
        (_) async => http.Response(jsonEncode(readFeedResponse()), 200));
    await store.saveGroupPlan(await GroupFeedService.calculate(
        group: group,
        availableFeeds: ['rumput', 'jerami', 'dedak'],
        client: client));
    final cattle = await store
        .saveCattle(Cattle(nameOrId: 'Budi', gender: 'Jantan', ageMonths: 18));
    await store.recordWeight(cattle.id, weightKg: 350, source: 'manual');
    await store.savePlan(legacyFeedPlan(
        cattle: store.cattle.single, createdAt: store.currentTime));
    await tester.pumpWidget(
        buildTestApp(store: store, home: const FeedShoppingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('1 profil individual dengan rencana terkini'),
        findsOneWidget);
    expect(find.text('191,1 kg'), findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Individual'))
            .selected,
        isTrue);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kelompok'));
    await tester.pumpAndSettle();
    expect(find.text('1 kelompok dengan rencana terkini'), findsOneWidget);
    expect(find.text('1911,0 kg'), findsOneWidget);
    expect(find.text('191,1 kg'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    client.close();
    store.dispose();
  });

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('Bulk group data and history fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FarmStore(read: () async => null, write: (_) async {});
      await store.load();
      final group = await store.createGroup('Kandang Penggemukan Utara',
          headCount: 100, averageWeightKg: 350);
      await tester.pumpWidget(buildTestApp(
          store: store, home: GroupDetailScreen(groupId: group.id)));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Histori perubahan data'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
}
