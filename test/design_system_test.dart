import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapiens_app/features/home/home_page.dart';
import 'package:sapiens_app/features/cattle/cattle_page.dart';
import 'package:sapiens_app/features/feed/feed_page.dart';
import 'package:sapiens_app/features/settings/settings_page.dart';
import 'package:sapiens_app/app/theme.dart';
import 'package:sapiens_app/features/cattle/add_cattle_page.dart';
import 'package:sapiens_app/features/milk/milk_editor_page.dart';
import 'package:sapiens_app/features/care/condition_page.dart';
import 'package:sapiens_app/domain/value.dart';
import 'package:sapiens_app/features/cattle/profile_page.dart';
import 'package:sapiens_app/features/feed/result_page.dart';
import 'package:sapiens_app/ui/components.dart';
import 'helpers/harness.dart';

void main() {
  double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
  }

  test('Shared foreground and semantic colors meet normal-text contrast', () {
    for (final pair in [
      (Palette.ink, Colors.white),
      (Palette.muted, Colors.white),
      (Palette.muted, Palette.cream),
      (Palette.ink, Palette.leaf),
      (Palette.amber, Palette.warningSurface),
      (Palette.error, Palette.errorSurface),
      (Colors.white, Palette.ink),
    ]) {
      expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    }
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(844, 390),
    const Size(1440, 900)
  ]) {
    testWidgets('Adaptive surfaces and long identity fit ${size.width}',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final h = Harness();
      addTearDown(h.dispose);
      await h.start(FarmMode.dairy);
      final c = await h.lactating();
      await h.controller.identity(c.id,
          name: 'Bintang Perah Kandang Utara Nomor Dua Belas',
          userId: 'PETERNAKAN-UTARA-2026-00000000000000001',
          ageMonths: 24,
          sex: Sex.female);
      final evaluation = await h.evaluate(c.id);
      for (final scale in [1.0, 1.6, 2.0]) {
        for (final page in [
          const HomePage(),
          const CattlePage(),
          const FeedPage(),
          const SettingsPage(),
          const AddCattlePage(),
          MilkEditorPage(cattle: h.data.find(c.id)!),
          ConditionPage(cattle: h.data.find(c.id)!),
          CattleProfilePage(cattleId: c.id),
          EvaluationResultPage(
              evaluation: evaluation, cattleName: h.data.find(c.id)!.name),
        ]) {
          await t.pumpWidget(UncontrolledProviderScope(
              container: h.container,
              child: MaterialApp(
                  key: ValueKey('${page.runtimeType}-$scale-${size.width}'),
                  theme: sapiensTheme(),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: page)));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull,
              reason: '${size.width}, text scale $scale, ${page.runtimeType}');
          if (page is CattleProfilePage && scale == 2 && size.width == 320) {
            for (final section in ProfileSection.values) {
              final tab = find.byKey(ValueKey('profile-${section.name}'));
              await t.scrollUntilVisible(tab, 200,
                  scrollable: find
                      .byWidgetPredicate((w) =>
                          w is Scrollable &&
                          w.axisDirection == AxisDirection.down)
                      .first,
                  maxScrolls: 30);
              await t.ensureVisible(tab);
              await t.pumpAndSettle();
              await t.tap(tab);
              await t.pumpAndSettle();
              expect(find.byKey(ValueKey('profile-body-${section.name}')),
                  findsOneWidget);
              expect(t.takeException(), isNull,
                  reason: 'Profile section ${section.name} at 200%');
            }
          }
        }
      }
    });
  }
  testWidgets('Secondary action has readable busy, error and retry states',
      (t) async {
    final pending = Completer<void>();
    var calls = 0;
    await t.pumpWidget(MaterialApp(
        theme: sapiensTheme(),
        home: Scaffold(
            body: SubmitButton(
                label: 'Pulihkan cadangan',
                secondary: true,
                submit: () {
                  calls++;
                  return calls == 1 ? pending.future : Future<void>.value();
                }))));
    await t.tap(find.text('Pulihkan cadangan'));
    await t.pump();
    expect(calls, 1);
    expect(
        t
            .widget<OutlinedButton>(
                find.byWidgetPredicate((w) => w is OutlinedButton))
            .onPressed,
        isNull);
    expect(
        t
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .color,
        Palette.ink);
    pending.completeError(StateError('File belum dapat dibaca. Coba lagi.'));
    await t.pumpAndSettle();
    expect(find.text('File belum dapat dibaca. Coba lagi.'), findsOneWidget);
    expect(t.widget<Notice>(find.byType(Notice)).error, isTrue);
    await t.tap(find.text('Pulihkan cadangan'));
    await t.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(Notice), findsNothing);
  });
  testWidgets(
      'Reduced-motion loading state is readable without endless animation',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: sapiensTheme(),
        home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: LoadingState()))));
    await t.pumpAndSettle();
    expect(find.text('Memuat data…'), findsOneWidget);
    expect(
        t
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        isNotNull);
    expect(t.takeException(), isNull);
  });
}
