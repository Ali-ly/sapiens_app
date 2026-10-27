import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/screens/beef/beef_dashboard_screen.dart';
import 'package:sapita_app/screens/beef/beef_module_screen.dart';
import 'package:sapita_app/screens/beef/beef_record_editor.dart';
import 'package:sapita_app/screens/beef/feed_stock_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_profile_screen.dart';
import 'package:sapita_app/screens/feed/feed_calculator_screen.dart';

import 'helpers/beef_environment.dart';
import 'helpers/nutrition_fixture.dart';
import 'helpers/test_app.dart';

Future<void> reveal(WidgetTester t, Finder f, {double delta = 220}) async {
  await t.scrollUntilVisible(f, delta,
      scrollable: find
          .descendant(
              of: find.byType(ListView).last, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 60);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

Future<void> open(WidgetTester t, BeefEnvironment e, Widget screen) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  await t.pumpWidget(buildTestApp(
      store: e.store,
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.push<void>(
                      context, MaterialPageRoute(builder: (_) => screen)),
                  child: const Text('Buka'))))));
  await t.tap(find.text('Buka'));
  await t.pumpAndSettle();
}

Future<void> saveNote(WidgetTester t, String note) async {
  await reveal(t, find.byKey(const ValueKey('beef-note')));
  await t.enterText(find.byKey(const ValueKey('beef-note')), note);
  await reveal(t, find.text('Simpan catatan Beef'));
  await t.tap(find.text('Simpan catatan Beef'));
  await t.pumpAndSettle();
}

Future<BeefEnvironment> environment() async {
  final e = BeefEnvironment();
  await e.store.load();
  addTearDown(e.store.dispose);
  return e;
}

void main() {
  testWidgets(
      'Profile to Beef purpose, phase and target is a usable end-to-end flow',
      (t) async {
    final e = await environment();
    final c = await e.add('Bima');
    await open(t, e, CattleProfileScreen(cattle: c));
    await reveal(t, find.text('Growth'));
    await t.tap(find.text('Growth'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(OutlinedButton, 'Tujuan Beef'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<BeefPurpose>));
    await t.pumpAndSettle();
    await t.tap(find.text('Penggemukan').last);
    await t.pumpAndSettle();
    await saveNote(t, 'Usaha dipilih pengguna');
    await reveal(t, find.widgetWithText(OutlinedButton, 'Fase Beef'));
    await t.tap(find.widgetWithText(OutlinedButton, 'Fase Beef'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<BeefPhase>));
    await t.pumpAndSettle();
    await t.tap(find.text('Finishing').last);
    await t.pumpAndSettle();
    await saveNote(t, 'Fase manual');
    await t.tap(find.widgetWithText(OutlinedButton, 'Target bobot'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('beef-target')), '500');
    await t.enterText(find.byKey(const ValueKey('beef-near')), '470');
    await saveNote(t, 'Target pilihan saya');
    final b = e.store.byId(c.id)!.modules.beef!;
    expect(b.purpose, BeefPurpose.fattening);
    expect(b.phase, BeefPhase.finishing);
    expect(b.records.length, 3);
    expect(b.latest(BeefRecordKind.target)!.nearKg, 470);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Beef Growth and Harvest expose arithmetic and user-defined readiness',
      (t) async {
    final e = await environment();
    final c = await e.add('Bima');
    await e.setup(c.id);
    await e.store.recordWeight(c.id, weightKg: 350, source: 'manual');
    e.now = e.now.add(const Duration(days: 10));
    await e.store.recordWeight(c.id, weightKg: 370, source: 'manual');
    await e.store.recordBeef(c.id,
        kind: BeefRecordKind.target,
        targetKg: 400,
        nearKg: 365,
        note: 'Target pengguna');
    await open(t, e, BeefModuleScreen(cattleId: c.id));
    expect(find.textContaining('ADG: 2.000 kg/hari'), findsOneWidget);
    expect(find.textContaining('Proyeksi linier: 15.0 hari'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'Harvest'));
    await t.pumpAndSettle();
    expect(find.text('Mendekati target'), findsOneWidget);
    expect(find.textContaining('pilihan pengguna'), findsOneWidget);
    expect(e.store.byId(c.id)!.isActive, isTrue);
  });
  testWidgets(
      'Beef calculator derives purpose without generic-mode acknowledgement',
      (t) async {
    final e = await environment();
    final c = await e.add('Bima');
    await e.setup(c.id);
    await e.store.recordWeight(c.id, weightKg: 350, source: 'manual');
    var calls = 0;
    await open(
        t,
        e,
        FeedCalculatorScreen(
            cattleId: c.id,
            loadFeeds: loadNutritionCatalog,
            evaluate: ({required request}) async {
              calls++;
              expect(request.cattle.toJson(), {
                'body_weight_kg': 350,
                'purpose': 'penggemukan',
                'target_adg_kg_day': 0.5
              });
              return evaluateNutrition(request: request);
            }));
    expect(find.textContaining('Saya memahami batas ransum generik'),
        findsNothing);
    expect(find.text('Apa target pemeliharaannya?'), findsNothing);
    await reveal(t, find.byKey(const ValueKey('nutrition-target-adg')));
    await t.enterText(
        find.byKey(const ValueKey('nutrition-target-adg')), '0.5');
    await reveal(t, find.byKey(const ValueKey('feed-select-rumput_gajah')));
    await t.tap(find.byKey(const ValueKey('feed-select-rumput_gajah')));
    await t.pumpAndSettle();
    await reveal(t, find.byKey(const ValueKey('feed-quantity-rumput_gajah')));
    await t.enterText(
        find.byKey(const ValueKey('feed-quantity-rumput_gajah')), '25');
    await reveal(t, find.text('Evaluasi nutrisi'));
    await t.tap(find.text('Evaluasi nutrisi'));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(e.store.feedPlans, isEmpty);
    expect(find.text('Hasil evaluasi nutrisi'), findsOneWidget);
  });
  testWidgets(
      'Pembibitan Feeding entry opens the v2 route without the generic Beef restriction',
      (t) async {
    final e = await environment();
    final c = await e.add('Induk', gender: 'Betina');
    await e.setup(c.id, purpose: BeefPurpose.breeding);
    await e.store.recordWeight(c.id, weightKg: 350, source: 'manual');
    await open(
        t, e, BeefModuleScreen(cattleId: c.id, initial: BeefSection.feeding));
    await reveal(t, find.text('Buka kalkulator pakan'));
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Buka kalkulator pakan'))
            .onPressed,
        isNotNull);
    expect(
        find.textContaining('Ransum Pembibitan belum didukung'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Pembibitan service to pregnancy to calving can be recorded through forms',
      (t) async {
    final e = await environment();
    final dam = await e.add('Induk', gender: 'Betina');
    final calf = await e.add('Anak');
    await e.setup(dam.id, purpose: BeefPurpose.breeding);
    await open(
        t,
        e,
        BeefRecordEditor(
            cattle: e.store.byId(dam.id)!, kind: BeefRecordKind.service));
    await saveNote(t, 'IB dicatat');
    final service = e.store.byId(dam.id)!.modules.beef!.records.last;
    await open(
        t,
        e,
        BeefRecordEditor(
            cattle: e.store.byId(dam.id)!, kind: BeefRecordKind.pregnancy));
    await t.tap(find.byType(DropdownButtonFormField<String>).first);
    await t.pumpAndSettle();
    await t.tap(find.textContaining('IB dicatat').last);
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<PregnancyResult>));
    await t.pumpAndSettle();
    await t.tap(find.text('Positif (catatan pengguna)').last);
    await t.pumpAndSettle();
    await saveNote(t, 'Pemeriksaan pengguna');
    final check = e.store.byId(dam.id)!.modules.beef!.records.last;
    expect(check.relatedId, service.id);
    await open(
        t,
        e,
        BeefRecordEditor(
            cattle: e.store.byId(dam.id)!, kind: BeefRecordKind.calving));
    await t.tap(find.byType(DropdownButtonFormField<String>).first);
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Pemeriksaan pengguna').last);
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Anak').last);
    await t.pumpAndSettle();
    await saveNote(t, 'Kelahiran manual');
    expect(e.store.byId(calf.id)!.core.references.damId, dam.id);
    await open(t, e,
        BeefModuleScreen(cattleId: dam.id, initial: BeefSection.reproduction));
    expect(find.widgetWithText(ChoiceChip, 'Reproduction'), findsOneWidget);
    await reveal(t, find.text('Kelahiran manual'));
    expect(find.text('Kelahiran manual'), findsOneWidget);
  });
  testWidgets(
      'Stock form preserves input after write failure and retries without auto consumption',
      (t) async {
    final e = await environment();
    await open(t, e, const StockEntryEditor());
    await t.enterText(find.byKey(const ValueKey('stock-kg')), '100');
    await t.enterText(find.byKey(const ValueKey('stock-note')), 'Pembelian');
    e.fail = true;
    await reveal(t, find.text('Simpan transaksi stok'));
    await t.tap(find.text('Simpan transaksi stok'));
    await t.pumpAndSettle();
    expect(e.store.feedStock, isEmpty);
    expect(find.text('100'), findsOneWidget);
    e.fail = false;
    await t.tap(find.text('Simpan transaksi stok'));
    await t.pumpAndSettle();
    expect(e.store.feedStock.single.kg, 100);
    await open(t, e, const FeedStockScreen());
    expect(find.textContaining('Stok 100,0 kg'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, '30 hari'));
    await t.pumpAndSettle();
    expect(find.textContaining('Kebutuhan 30 hari'), findsWidgets);
    expect(e.store.feedStock.length, 1);
  });
  testWidgets(
      'Beef dashboard separates purposes/category/status and inactive forms are disabled',
      (t) async {
    final e = await environment();
    final a = await e.add('Aktif');
    final b = await e.add('Keluar');
    await e.setup(a.id);
    await e.setup(b.id, purpose: BeefPurpose.breeding);
    await e.store.setCattleStatus(b.id, CattleStatus.sold);
    await e.add('Dairy', category: ProductionCategory.dairy);
    await open(t, e, const BeefDashboardScreen());
    expect(find.text('Aktif').last, findsOneWidget);
    expect(find.text('Keluar'), findsNothing);
    expect(find.text('Dairy'), findsNothing);
    await t.tap(find.widgetWithText(ChoiceChip, 'Nonaktif'));
    await t.pumpAndSettle();
    expect(find.text('Keluar'), findsOneWidget);
    await open(
        t,
        e,
        BeefRecordEditor(
            cattle: e.store.byId(b.id)!, kind: BeefRecordKind.purpose));
    await reveal(t, find.text('Simpan catatan Beef'));
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Simpan catatan Beef'))
            .onPressed,
        isNull);
  });
  testWidgets(
      'Invalid Beef time and stale save retain input; back requires a choice',
      (t) async {
    final e = await environment();
    final c = await e.add('Bima');
    await open(t, e, BeefRecordEditor(cattle: c, kind: BeefRecordKind.purpose));
    await t.tap(find.byType(DropdownButtonFormField<BeefPurpose>));
    await t.pumpAndSettle();
    await t.tap(find.text('Penggemukan').last);
    await t.pumpAndSettle();
    final time = t
        .widget<TextFormField>(find.byKey(const ValueKey('beef-occurred')))
        .controller!
        .text;
    await t.enterText(
        find.byKey(const ValueKey('beef-occurred')), '2026-02-31 10:00');
    await saveNote(t, 'Input tetap ada');
    expect(find.text('Waktu tidak valid.'), findsOneWidget);
    expect(e.store.byId(c.id)!.modules.beef, isNull);
    await reveal(t, find.byKey(const ValueKey('beef-occurred')), delta: -220);
    await t.enterText(find.byKey(const ValueKey('beef-occurred')), time);
    await e.setup(c.id);
    await reveal(t, find.text('Simpan catatan Beef'));
    await t.tap(find.text('Simpan catatan Beef'));
    await t.pumpAndSettle();
    expect(find.textContaining('Catatan Beef berubah'), findsOneWidget);
    expect(find.text('Input tetap ada'), findsOneWidget);
    await reveal(t, find.byTooltip('Kembali'), delta: -220);
    await t.tap(find.byTooltip('Kembali'));
    await t.pumpAndSettle();
    expect(find.text('Perubahan belum disimpan'), findsOneWidget);
    await t.tap(find.text('Lanjut mengisi'));
    await t.pumpAndSettle();
    expect(find.byType(BeefRecordEditor), findsOneWidget);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('Beef pages and forms fit width $width', (t) async {
      final e = await environment();
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = await e.add('Induk panjang', gender: 'Betina');
      await e.setup(c.id, purpose: BeefPurpose.breeding);
      for (final page in [
        BeefModuleScreen(cattleId: c.id),
        BeefRecordEditor(
            cattle: e.store.byId(c.id)!, kind: BeefRecordKind.calving),
        const FeedStockScreen(),
        const StockEntryEditor(),
        const BeefDashboardScreen()
      ]) {
        await open(t, e, page);
        expect(t.takeException(), isNull);
      }
    });
  }
}
