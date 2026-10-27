import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/screens/cattle/cattle_profile_screen.dart';
import 'package:sapita_app/screens/dairy/dairy_dashboard_screen.dart';
import 'package:sapita_app/screens/dairy/dairy_module_screen.dart';
import 'package:sapita_app/screens/dairy/dairy_record_editor.dart';
import 'package:sapita_app/screens/dairy/milk_editor.dart';

import 'helpers/dairy_environment.dart';
import 'helpers/test_app.dart';

Future<DairyEnvironment> environment() async {
  final e = DairyEnvironment();
  await e.store.load();
  addTearDown(e.store.dispose);
  return e;
}

Future<void> open(WidgetTester t, DairyEnvironment e, Widget page) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  await t.pumpWidget(buildTestApp(
      store: e.store,
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.push<void>(
                      context, MaterialPageRoute(builder: (_) => page)),
                  child: const Text('Buka'))))));
  await t.tap(find.text('Buka'));
  await t.pumpAndSettle();
}

Future<void> reveal(WidgetTester t, Finder f, {double delta = 220}) async {
  await t.scrollUntilVisible(f, delta,
      scrollable: find
          .descendant(
              of: find.byType(ListView).last, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 80);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

Future<void> dairySave(WidgetTester t, String note) async {
  await reveal(t, find.byKey(const ValueKey('dairy-note')));
  await t.enterText(find.byKey(const ValueKey('dairy-note')), note);
  await reveal(t, find.text('Simpan catatan Dairy'));
  await t.tap(find.text('Simpan catatan Dairy'));
  await t.pumpAndSettle();
}

Future<void> milkSave(WidgetTester t, String note) async {
  await reveal(t, find.byKey(const ValueKey('milk-note')));
  await t.enterText(find.byKey(const ValueKey('milk-note')), note);
  await reveal(t, find.text('Simpan susu'));
  await t.tap(find.text('Simpan susu'));
  await t.pumpAndSettle();
}

void noOpaqueIds(WidgetTester t, Cattle c) {
  final ids = [
    ...?c.modules.dairy?.records.map((r) => r.id),
    ...?c.modules.dairy?.milk.map((r) => r.id),
    ...c.core.health.map((r) => r.id)
  ];
  for (final text in t.widgetList<Text>(find.byType(Text))) {
    for (final id in ids) {
      expect(text.data?.contains(id) ?? false, isFalse);
    }
  }
}

void main() {
  testWidgets(
      'Pregnancy picker excludes pre-calving same-day breeding and uses the new cycle service',
      (t) async {
    final e = await environment(), c = await e.add('Boundary');
    await e.birth(c.id, '2026-10-01');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service,
        day: '2026-10-26',
        note: 'Servis sebelum kelahiran');
    await e.birth(c.id, '2026-10-26');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.service,
        day: '2026-10-26',
        note: 'Servis siklus baru');
    await open(
        t,
        e,
        DairyRecordEditor(
            cattle: e.store.byId(c.id)!, kind: DairyRecordKind.pregnancy));
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    expect(find.textContaining('Servis sebelum kelahiran'), findsNothing);
    expect(find.textContaining('Servis siklus baru'), findsOneWidget);
    await t.tap(find.textContaining('Servis siklus baru'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<PregnancyResult>));
    await t.pumpAndSettle();
    await t.tap(find.text('Positif').last);
    await t.pumpAndSettle();
    await t
        .tap(find.text('Saya mengonfirmasi breeding terkait sebagai konsepsi'));
    await t.pumpAndSettle();
    await dairySave(t, 'Konfirmasi pengguna');
    await open(t, e,
        DairyModuleScreen(cattleId: c.id, initial: DairySection.reproduction));
    expect(
        find.text('Servis tercatat sampai konsepsi (S/C): 1'), findsOneWidget);
  });
  testWidgets(
      'Individual profile to AM entry, PM correction and daily ledger is usable',
      (t) async {
    final e = await environment(), c = await e.add('Nanda');
    await open(t, e, CattleProfileScreen(cattle: c));
    await reveal(t, find.text('Milk'));
    await t.tap(find.text('Milk'));
    await t.pumpAndSettle();
    await reveal(t, find.text('Catat susu hari ini'));
    await t.tap(find.text('Catat susu hari ini'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<MilkMode>));
    await t.pumpAndSettle();
    await t.tap(find.text('AM + PM').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('milk-am')), '12');
    await milkSave(t, 'Pagi tercatat');
    expect(e.store.dairyMilk.liters, 12);
    expect(e.store.dairyMilk.partialCows, 1);
    await reveal(t, find.text('Lengkapi / koreksi hari ini'));
    await t.tap(find.text('Lengkapi / koreksi hari ini'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('milk-pm')), '8');
    await milkSave(t, 'Sore dilengkapi');
    expect(e.store.dairyMilk.liters, 20);
    expect(e.store.dairyMilk.completeCows, 1);
    expect(e.store.byId(c.id)!.modules.dairy!.milk.length, 2);
    await reveal(t, find.text('Ledger susu (termasuk koreksi)'));
    await reveal(t,
        find.textContaining('Koreksi snapshot 2026-10-26 yang dicatat').first);
    noOpaqueIds(t, e.store.byId(c.id)!);
  });
  testWidgets(
      'Fresh/Early/Dry/CloseUp are separate manual choices and preserve cycle',
      (t) async {
    final e = await environment(), c = await e.add('Nanda');
    await e.birth(c.id, '2026-10-01');
    for (final phase in [
      DairyPhase.fresh,
      DairyPhase.early,
      DairyPhase.dry,
      DairyPhase.closeUp
    ]) {
      await open(
          t,
          e,
          DairyRecordEditor(
              cattle: e.store.byId(c.id)!, kind: DairyRecordKind.phase));
      await t.tap(find.byType(DropdownButtonFormField<DairyPhase>));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(dairyPhaseLabels[phase]!).last);
      await t.tap(find.text(dairyPhaseLabels[phase]!).last);
      await t.pumpAndSettle();
      await dairySave(t, 'Pilihan fase');
      expect(e.store.byId(c.id)!.modules.dairy!.phase, phase);
    }
    expect(e.store.byId(c.id)!.modules.dairy!.calvings.length, 1);
  });
  testWidgets(
      'Actual calving form starts DIM zero and next calving increments explicit parity',
      (t) async {
    final e = await environment(), c = await e.add('Nanda');
    await open(
        t, e, DairyRecordEditor(cattle: c, kind: DairyRecordKind.calving));
    await t.enterText(find.byKey(const ValueKey('dairy-parity')), '3');
    await reveal(t, find.byKey(const ValueKey('dairy-day')));
    await t.enterText(find.byKey(const ValueKey('dairy-day')), '2026-10-01');
    await dairySave(t, 'Kelahiran aktual');
    final calf = await e.add('Pedet');
    await open(
        t,
        e,
        DairyRecordEditor(
            cattle: e.store.byId(c.id)!, kind: DairyRecordKind.calving));
    await reveal(t, find.byType(DropdownButtonFormField<String>).last);
    await t.tap(find.byType(DropdownButtonFormField<String>).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Pedet').last);
    await t.pumpAndSettle();
    await dairySave(t, 'Kelahiran berikutnya');
    expect(e.store.byId(c.id)!.modules.dairy!.calvings.last.parity, 4);
    expect(e.store.byId(calf.id)!.core.references.damId, c.id);
    await open(t, e,
        DairyModuleScreen(cattleId: c.id, initial: DairySection.lactation));
    expect(find.textContaining('DIM kalender: 0'), findsOneWidget);
    expect(find.textContaining('paritas 4'), findsOneWidget);
    expect(e.store.byId(calf.id)!.ageMonths, 18);
  });
  testWidgets(
      'Reproduction forms use confirmed service for metrics and show readable references',
      (t) async {
    final e = await environment(), c = await e.add('Nanda');
    await e.birth(c.id, '2026-09-01');
    await open(
        t,
        e,
        DairyRecordEditor(
            cattle: e.store.byId(c.id)!, kind: DairyRecordKind.service));
    await t.enterText(find.byKey(const ValueKey('dairy-day')), '2026-10-01');
    await dairySave(t, 'IB tercatat');
    await open(
        t,
        e,
        DairyRecordEditor(
            cattle: e.store.byId(c.id)!, kind: DairyRecordKind.pregnancy));
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('IB tercatat').last);
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<PregnancyResult>));
    await t.pumpAndSettle();
    await t.tap(find.text('Positif').last);
    await t.pumpAndSettle();
    await t
        .tap(find.text('Saya mengonfirmasi breeding terkait sebagai konsepsi'));
    await t.pumpAndSettle();
    await dairySave(t, 'Pemeriksaan manual');
    await open(t, e,
        DairyModuleScreen(cattleId: c.id, initial: DairySection.reproduction));
    expect(find.textContaining('Days Open ke konsepsi tercatat: 30 hari'),
        findsOneWidget);
    await reveal(t, find.textContaining('Terkait: Breeding / IB'));
    noOpaqueIds(t, e.store.byId(c.id)!);
  });
  testWidgets(
      'User withholding dates and explicit correction change totals, health link stays readable',
      (t) async {
    final e = await environment(), c = await e.add('Nanda');
    await e.store.recordMilk(c.id,
        day: '2026-10-26', mode: MilkMode.daily, total: 20, note: 'Harian');
    await e.store.recordHealth(c.id,
        kind: HealthKind.treatment,
        occurredAt: e.now,
        note: 'Tindakan dari pengguna');
    await open(
        t,
        e,
        DairyRecordEditor(
            cattle: e.store.byId(c.id)!, kind: DairyRecordKind.udder));
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Tindakan dari pengguna').last);
    await t.pumpAndSettle();
    await dairySave(t, 'Observasi ambing');
    await open(
        t,
        e,
        DairyRecordEditor(
            cattle: e.store.byId(c.id)!, kind: DairyRecordKind.withholding));
    await t.enterText(
        find.byKey(const ValueKey('dairy-safe-day')), '2026-10-30');
    await t.enterText(find.byKey(const ValueKey('dairy-day')), '2026-10-20');
    await dairySave(t, 'Arahan vet pengguna');
    expect(e.store.dairyMilk.withheld, 20);
    await open(
        t,
        e,
        DairyRecordEditor(
            cattle: e.store.byId(c.id)!, kind: DairyRecordKind.withholding));
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Arahan vet pengguna').last);
    await t.pumpAndSettle();
    await t.enterText(
        find.byKey(const ValueKey('dairy-safe-day')), '2026-10-25');
    await t.enterText(find.byKey(const ValueKey('dairy-day')), '2026-10-20');
    await dairySave(t, 'Koreksi sumber');
    expect(e.store.dairyMilk.withheld, 0);
    expect(e.store.dairyMilk.outsideHold, 20);
    await open(
        t, e, DairyModuleScreen(cattleId: c.id, initial: DairySection.udder));
    await reveal(t, find.textContaining('Kesehatan terkait:'));
    noOpaqueIds(t, e.store.byId(c.id)!);
  });
  testWidgets(
      'Dairy dashboard quick entry and functional phase filters keep individual and active scope',
      (t) async {
    final e = await environment(),
        a = await e.add('Nanda'),
        b = await e.add('Bella'),
        old = await e.add('Arsip');
    await e.store.recordDairy(a.id,
        kind: DairyRecordKind.phase,
        phase: DairyPhase.fresh,
        day: '2026-10-26',
        note: 'Fresh');
    await e.store.recordDairy(b.id,
        kind: DairyRecordKind.phase,
        phase: DairyPhase.early,
        day: '2026-10-26',
        note: 'Early');
    await e.store.recordDairy(old.id,
        kind: DairyRecordKind.phase,
        phase: DairyPhase.fresh,
        day: '2026-10-26',
        note: 'Fresh');
    await e.store.setCattleStatus(old.id, CattleStatus.archived);
    await open(t, e, const DairyDashboardScreen());
    await reveal(t, find.widgetWithText(ChoiceChip, 'Fresh Cow'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Fresh Cow'));
    await t.pumpAndSettle();
    await reveal(t, find.byKey(ValueKey('quick-milk-${a.id}')));
    expect(find.text('Bella'), findsNothing);
    await t.tap(find.byKey(ValueKey('quick-milk-${a.id}')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('milk-total')), '15');
    await milkSave(t, 'Quick entry');
    expect(e.store.dairyMilk.liters, 15);
    await reveal(t, find.widgetWithText(ChoiceChip, 'Nonaktif'), delta: -220);
    await t.tap(find.widgetWithText(ChoiceChip, 'Nonaktif'));
    await t.pumpAndSettle();
    await reveal(t, find.text('Arsip'));
    expect(e.store.dairyMilk.totalCows, 2);
  });
  testWidgets(
      'Failed milk write retains input, retry succeeds once, inactive form disabled',
      (t) async {
    final e = await environment(), c = await e.add('Nanda');
    await open(t, e, MilkEditor(cattle: c));
    await t.enterText(find.byKey(const ValueKey('milk-total')), '10');
    e.fail = true;
    await milkSave(t, 'Tetap ada');
    expect(e.store.dairyMilk.liters, 0);
    expect(find.text('10'), findsOneWidget);
    e.fail = false;
    await t.tap(find.text('Simpan susu'));
    await t.pumpAndSettle();
    expect(e.store.dairyMilk.liters, 10);
    await e.store.setCattleStatus(c.id, CattleStatus.sold);
    await open(t, e, MilkEditor(cattle: e.store.byId(c.id)!));
    await reveal(t, find.text('Simpan susu'));
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Simpan susu'))
            .onPressed,
        isNull);
    expect(e.store.byId(c.id)!.modules.dairy!.milk.length, 1);
  });
  testWidgets(
      'Invalid calendar and stale Dairy form preserve input and unsaved guard',
      (t) async {
    final e = await environment(), c = await e.add('Nanda');
    await open(t, e, MilkEditor(cattle: c));
    await t.enterText(find.byKey(const ValueKey('milk-day')), '2026-02-31');
    await t.enterText(find.byKey(const ValueKey('milk-total')), '10');
    await milkSave(t, 'Belum hilang');
    expect(find.textContaining('Tanggal harus valid'), findsOneWidget);
    await reveal(t, find.byKey(const ValueKey('milk-day')), delta: -220);
    await t.enterText(find.byKey(const ValueKey('milk-day')), '2026-10-26');
    await e.store.recordDairy(c.id,
        kind: DairyRecordKind.phase,
        phase: DairyPhase.fresh,
        day: '2026-10-26',
        note: 'Concurrent');
    await reveal(t, find.text('Simpan susu'));
    await t.tap(find.text('Simpan susu'));
    await t.pumpAndSettle();
    expect(find.textContaining('Catatan Dairy berubah'), findsOneWidget);
    await reveal(t, find.byTooltip('Kembali'), delta: -220);
    await t.tap(find.byTooltip('Kembali'));
    await t.pumpAndSettle();
    expect(find.text('Perubahan belum disimpan'), findsOneWidget);
    await t.tap(find.text('Lanjut mengisi'));
    await t.pumpAndSettle();
    expect(find.byType(MilkEditor), findsOneWidget);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('Dairy pages fit width $width without clinical assumptions',
        (t) async {
      final e = await environment();
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = await e.add('Nama sapi Dairy');
      await e.birth(c.id, '2026-10-01');
      for (final page in [
        DairyModuleScreen(cattleId: c.id),
        DairyModuleScreen(cattleId: c.id, initial: DairySection.lactation),
        DairyModuleScreen(cattleId: c.id, initial: DairySection.feeding),
        DairyRecordEditor(
            cattle: e.store.byId(c.id)!, kind: DairyRecordKind.pregnancy),
        const DairyDashboardScreen(),
        MilkEditor(cattle: e.store.byId(c.id)!)
      ]) {
        await open(t, e, page);
        expect(t.takeException(), isNull);
      }
    });
  }
}
