import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapiens_app/app/app.dart';
import 'package:sapiens_app/app/theme.dart';
import 'package:sapiens_app/application/providers.dart';
import 'package:sapiens_app/domain/condition.dart';
import 'package:sapiens_app/domain/value.dart';
import 'package:sapiens_app/features/cattle/add_cattle_page.dart';
import 'package:sapiens_app/features/cattle/profile_page.dart';
import 'package:sapiens_app/features/feed/evaluation_page.dart';
import 'package:sapiens_app/features/feed/result_page.dart';
import 'package:sapiens_app/features/milk/milk_editor_page.dart';
import 'package:sapiens_app/features/settings/settings_page.dart';

import 'helpers/harness.dart';

void main() {
  Future<Harness> env(FarmMode mode) async {
    final h = Harness();
    addTearDown(h.dispose);
    await h.start(mode);
    return h;
  }

  Future<void> mount(WidgetTester t, Harness h, Widget page) async {
    await t.pumpWidget(UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(theme: sapiensTheme(), home: page)));
    await t.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester t, Finder finder,
      {double delta = 200}) async {
    await t.scrollUntilVisible(finder, delta,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .last,
        maxScrolls: 50);
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String text) async {
    final scope = FocusManager.instance.primaryFocus;
    scope?.unfocus();
    await t.pumpAndSettle();
    final finder = find.text(text);
    await reveal(t, finder);
    await t.tap(finder.last);
    await t.pumpAndSettle();
  }

  Future<void> choose<T>(WidgetTester t, String label, String value) async {
    final f = find.widgetWithText(DropdownButtonFormField<T>, label);
    await reveal(t, f);
    await t.tap(f);
    await t.pumpAndSettle();
    await t.tap(find.text(value).last);
    await t.pumpAndSettle();
  }

  Future<void> identity(WidgetTester t) async {
    await t.enterText(find.byKey(const ValueKey('cattle-name')), 'Sari');
    await t.enterText(find.byKey(const ValueKey('cattle-age')), '24');
    await tap(t, 'Lanjut: bobot & kondisi');
  }

  for (final mode in FarmMode.values) {
    testWidgets(
        '${mode.name}: first use selects account mode once and exposes four primary destinations',
        (t) async {
      final h = Harness();
      addTearDown(h.dispose);
      await h.container.read(farmProvider.future);
      await t.pumpWidget(UncontrolledProviderScope(
          container: h.container, child: const SapiensApp()));
      await t.pumpAndSettle();
      await reveal(t, find.byKey(ValueKey('mode-${mode.name}')));
      await t.tap(find.byKey(ValueKey('mode-${mode.name}')));
      await t.pumpAndSettle();
      await tap(t, 'Mulai peternakanku');
      expect(h.data.account!.mode, mode);
      expect(find.byType(NavigationBar), findsOneWidget);
      final nav = t.widget<NavigationBar>(find.byType(NavigationBar));
      expect(nav.destinations, hasLength(4));
      expect(
          find.descendant(
              of: find.byType(NavigationBar), matching: find.text('Beranda')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(NavigationBar), matching: find.text('Ternak')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(NavigationBar), matching: find.text('Pakan')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(NavigationBar), matching: find.text('Profil')),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets(
        '${mode.name}: two-step creation requires initial weight and shows adaptive context',
        (t) async {
      final h = await env(mode);
      await mount(t, h, const AddCattlePage());
      expect(
          t
              .widget<DropdownButtonFormField<Sex>>(
                  find.byType(DropdownButtonFormField<Sex>))
              .initialValue,
          mode == FarmMode.beef ? Sex.male : Sex.female);
      expect(find.byKey(const ValueKey('weight-input')), findsNothing);
      expect(find.textContaining('Ras'), findsNothing);
      await identity(t);
      await tap(t, 'Simpan Sapi');
      expect(h.data.cattle, isEmpty);
      expect(find.textContaining('Bobot awal wajib.'), findsOneWidget);
      await reveal(t, find.byKey(const ValueKey('weight-input')), delta: -200);
      await t.enterText(find.byKey(const ValueKey('weight-input')), '300');
      await t.pumpAndSettle();
      if (mode == FarmMode.beef) {
        await choose<BeefPurpose>(t, 'Tujuan pemeliharaan', 'Penggemukan');
        await choose<FatteningPhase>(t, 'Fase penggemukan', 'Penggemukan Awal');
      } else {
        await choose<DairyStage>(t, 'Fase fisiologis', 'Baru beranak / Fresh');
      }
      await tap(t, 'Simpan Sapi');
      expect(h.data.cattle, hasLength(1));
      expect(h.data.cattle.single.weights, hasLength(1));
      expect(h.data.cattle.single.photos, isEmpty);
      expect(find.byType(CattleProfilePage), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-summary')), findsOneWidget);
      expect(find.text('Produksi Susu'),
          mode == FarmMode.dairy ? findsOneWidget : findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'Returning to identity preserves weight and condition draft instead of saving an invisible value',
      (t) async {
    final h = await env(FarmMode.beef);
    await mount(t, h, const AddCattlePage());
    await identity(t);
    await t.enterText(find.byKey(const ValueKey('weight-input')), '300');
    await t.pumpAndSettle();
    await choose<BeefPurpose>(t, 'Tujuan pemeliharaan', 'Penggemukan');
    await choose<FatteningPhase>(t, 'Fase penggemukan', 'Penggemukan Awal');
    await tap(t, 'Kembali ke identitas');
    await tap(t, 'Lanjut: bobot & kondisi');
    expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('weight-input')))
            .controller!
            .text,
        '300');
    expect(
        t
            .widget<DropdownButtonFormField<BeefPurpose>>(
                find.byType(DropdownButtonFormField<BeefPurpose>))
            .initialValue,
        BeefPurpose.fattening);
    await tap(t, 'Simpan Sapi');
    expect(h.data.cattle.single.latestWeight.kg, 300);
  });
  testWidgets(
      'Female breeding asks pregnancy while male breeding has no female fields',
      (t) async {
    final h = await env(FarmMode.beef);
    await mount(t, h, const AddCattlePage());
    await choose<Sex>(t, 'Jenis kelamin', 'Betina');
    await identity(t);
    await t.enterText(find.byKey(const ValueKey('weight-input')), '300');
    await t.pumpAndSettle();
    await choose<BeefPurpose>(t, 'Tujuan pemeliharaan', 'Pembibitan');
    expect(find.text('Fase penggemukan'), findsNothing);
    expect(find.byType(DropdownButtonFormField<Pregnancy>), findsOneWidget);
    await choose<Pregnancy>(t, 'Status reproduksi', 'Belum pasti');
    await tap(t, 'Simpan Sapi');
    expect((h.data.cattle.single.condition as BeefCondition).pregnancy,
        Pregnancy.uncertain);
  });
  testWidgets(
      'Dairy male has no physiological fields and production tab cannot be opened',
      (t) async {
    final h = await env(FarmMode.dairy);
    await mount(t, h, const AddCattlePage());
    await choose<Sex>(t, 'Jenis kelamin', 'Jantan');
    await identity(t);
    await t.enterText(find.byKey(const ValueKey('weight-input')), '300');
    await t.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<DairyStage>), findsNothing);
    await tap(t, 'Simpan Sapi');
    final chip =
        t.widget<ChoiceChip>(find.byKey(const ValueKey('profile-milk')));
    expect(chip.onSelected, isNull);
    expect(find.text('Catat produksi susu'), findsNothing);
    expect(h.data.cattle.single.sex, Sex.male);
  });
  testWidgets(
      'Failed creation keeps entered values and retry adds exactly one cattle',
      (t) async {
    final h = await env(FarmMode.dairy);
    await mount(t, h, const AddCattlePage());
    await identity(t);
    await t.enterText(find.byKey(const ValueKey('weight-input')), '500');
    await t.pumpAndSettle();
    await choose<DairyStage>(t, 'Fase fisiologis', 'Laktasi awal');
    h.storage.fail = true;
    await tap(t, 'Simpan Sapi');
    expect(h.data.cattle, isEmpty);
    expect(find.text('Penyimpanan penuh'), findsOneWidget);
    h.storage.fail = false;
    await tap(t, 'Simpan Sapi');
    expect(h.data.cattle, hasLength(1));
    expect(h.data.cattle.single.latestWeight.kg, 500);
  });
  testWidgets(
      'Feed profile route does not reselect cattle/mode and persists backend evaluation',
      (t) async {
    final h = await env(FarmMode.beef), c = await h.add();
    await mount(t, h, FeedEvaluationPage(cattleId: c.id));
    expect(find.text('Pilih Sapi'), findsNothing);
    expect(find.text('Peternak Sapi Perah'), findsNothing);
    await reveal(t, find.byKey(const ValueKey('feed-rumput_gajah')));
    await t.tap(find.byKey(const ValueKey('feed-rumput_gajah')));
    await t.pumpAndSettle();
    await reveal(t, find.byKey(const ValueKey('amount-rumput_gajah')));
    await t.enterText(find.byKey(const ValueKey('amount-rumput_gajah')), '25');
    await tap(t, 'Evaluasi & simpan');
    expect(h.gateway.nutritionCalls, 1);
    expect(h.data.find(c.id)!.evaluations, hasLength(1));
    expect(find.byType(EvaluationResultPage), findsOneWidget);
  });
  testWidgets(
      'Dairy partial result never relabels nutrient as enough/deficient',
      (t) async {
    final h = await env(FarmMode.dairy),
        c = await h.lactating(),
        e = await h.evaluate(c.id);
    await mount(t, h, EvaluationResultPage(evaluation: e, cattleName: c.name));
    expect(find.textContaining('Belum dapat dievaluasi penuh'), findsWidgets);
    expect(find.text('Cukup'), findsNothing);
    expect(find.text('Kurang'), findsNothing);
    expect(find.text('Confidence'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Partial AM recording and same-day correction retain original session',
      (t) async {
    final h = await env(FarmMode.dairy), c = await h.add();
    await mount(t, h, MilkEditorPage(cattle: c));
    await tap(t, 'Pagi / Sore');
    await reveal(t, find.byKey(const ValueKey('milk-am')));
    await t.enterText(find.byKey(const ValueKey('milk-am')), '8');
    await tap(t, 'Simpan produksi susu');
    expect(h.data.find(c.id)!.milk.single.pm, isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    final current = h.data.find(c.id)!;
    await mount(
        t, h, MilkEditorPage(cattle: current, record: current.milk.last));
    expect(
        double.parse(t
            .widget<TextFormField>(find.byKey(const ValueKey('milk-am')))
            .controller!
            .text),
        8);
    await reveal(t, find.byKey(const ValueKey('milk-pm')));
    await t.enterText(find.byKey(const ValueKey('milk-pm')), '6');
    await tap(t, 'Simpan koreksi');
    expect(h.data.find(c.id)!.milk, hasLength(2));
    expect(h.data.find(c.id)!.milk.last.recordedAmount, 14);
  });
  testWidgets(
      'Switch mode requires typed confirmation, cancellation preserves full account data',
      (t) async {
    final h = await env(FarmMode.beef);
    await h.add();
    await mount(t, h, const SettingsPage());
    await reveal(t, find.text('Ganti Jenis Peternakan'));
    await t.tap(find.text('Ganti Jenis Peternakan'));
    await t.pump(const Duration(milliseconds: 500));
    expect(
        t
            .widget<FilledButton>(
                find.byKey(const ValueKey('confirm-mode-delete')))
            .onPressed,
        isNull);
    await t.tap(find.text('Batal'));
    await t.pumpAndSettle();
    expect(h.data.cattle, hasLength(1));
    await reveal(t, find.text('Ganti Jenis Peternakan'));
    await t.tap(find.text('Ganti Jenis Peternakan'));
    await t.pump(const Duration(milliseconds: 500));
    await t.enterText(find.byKey(const ValueKey('confirm-mode-text')), 'GANTI');
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.byKey(const ValueKey('confirm-mode-delete')));
    await t.pumpAndSettle();
    expect(h.data.cattle, isEmpty);
    expect(h.data.account!.mode, FarmMode.dairy);
  });
  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('New adaptive profile and all primary pages fit width $width',
        (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final h = await env(FarmMode.dairy), c = await h.lactating();
      await t.pumpWidget(UncontrolledProviderScope(
          container: h.container, child: const SapiensApp()));
      await t.pumpAndSettle();
      for (final label in ['Ternak', 'Pakan', 'Profil', 'Beranda']) {
        await t.tap(find.descendant(
            of: find.byType(NavigationBar), matching: find.text(label)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      await mount(t, h, CattleProfilePage(cattleId: c.id));
      for (final section in ProfileSection.values) {
        await t.ensureVisible(find.byKey(ValueKey('profile-${section.name}')));
        await t.tap(find.byKey(ValueKey('profile-${section.name}')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
    });
  }
}
