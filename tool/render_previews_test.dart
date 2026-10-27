// Local visual QA with synthetic cattle; never writes to device account storage.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapiens_app/app/app.dart';
import 'package:sapiens_app/app/theme.dart';
import 'package:sapiens_app/application/providers.dart';
import 'package:sapiens_app/domain/value.dart';
import 'package:sapiens_app/domain/records.dart';
import 'package:sapiens_app/api/contracts.dart';
import 'package:sapiens_app/features/cattle/profile_page.dart';
import 'package:sapiens_app/features/feed/result_page.dart';
import '../test/helpers/harness.dart';

void main() {
  testWidgets('Render synthetic MVP previews', (t) async {
    final output = Directory(const String.fromEnvironment('PREVIEW_DIR',
        defaultValue: '/tmp/sapiens-previews'));
    await t.runAsync(() => output.create(recursive: true));
    final root = Platform.environment['FLUTTER_ROOT'] ??
        '/Users/mac/Documents/Code/Flutter/flutter';
    await t.runAsync(() async {
      for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
        final loader = FontLoader(family);
        final names = family != 'MaterialIcons'
            ? ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']
            : ['MaterialIcons-Regular.otf'];
        for (final name in names) {
          loader.addFont(File('$root/bin/cache/artifacts/material_fonts/$name')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)));
        }
        await loader.load();
      }
    });
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Future<void> capture(String name, Harness h, Widget page,
        {bool app = false, double width = 390, double textScale = 1}) async {
      t.view.physicalSize = Size(width, width > 600 ? 960 : 844);
      final key = GlobalKey();
      await t.pumpWidget(UncontrolledProviderScope(
          container: h.container,
          child: RepaintBoundary(
              key: key,
              child: app
                  ? page
                  : MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: sapiensTheme(),
                      builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              textScaler: TextScaler.linear(textScale)),
                          child: child!),
                      home: page))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    final empty = Harness();
    await empty.container.read(farmProvider.future);
    await capture('onboarding', empty, const SapiensApp(), app: true);
    await t.pumpWidget(const SizedBox());
    empty.dispose();
    for (final mode in FarmMode.values) {
      final h = Harness();
      await h.start(mode);
      final c = mode == FarmMode.beef
          ? await h.add(name: 'Bima')
          : await h.lactating();
      await h.controller.identity(c.id,
          name: mode == FarmMode.beef ? 'Bima' : 'Sari',
          userId: 'SP-001',
          ageMonths: 24,
          sex: c.sex);
      final evaluation = await h.controller.evaluate(
          c.id,
          [
            FeedAmount('rumput_gajah', mode == FarmMode.beef ? 25 : 30),
            FeedAmount('dedak_padi_bekatul', mode == FarmMode.beef ? 3 : 4),
          ],
          await h.gateway.feeds(mode));
      await capture('${mode.name}-home', h, const SapiensApp(), app: true);
      await capture(
          '${mode.name}-profile', h, CattleProfilePage(cattleId: c.id));
      await capture(
          '${mode.name}-result',
          h,
          EvaluationResultPage(
              evaluation: evaluation,
              cattleName: mode == FarmMode.beef ? 'Bima' : 'Sari'));
      await capture(
          '${mode.name}-result-wide',
          h,
          EvaluationResultPage(
              evaluation: evaluation,
              cattleName: mode == FarmMode.beef ? 'Bima' : 'Sari'),
          width: 1280);
      if (mode == FarmMode.beef) {
        final screenshotExample = NutritionEvaluation(
            id: 'screenshot-example',
            createdAt: h.now,
            contextHash: 'presentation-only',
            contextSnapshot: const {},
            request: const {
              'production_category': 'beef',
              'cattle': {'body_weight_kg': 200},
              'feed_items': []
            },
            response: const {
              'status': 'ok',
              'production_category': 'beef',
              'adequacy': {
                'dry_matter': {
                  'requirement': 5.60,
                  'supply': 0.41,
                  'unit': 'kg/day',
                  'adequacy_pct': 7.26,
                  'profile_coverage_fraction': 1,
                  'status': 'deficient'
                }
              }
            });
        await capture(
            'screenshot-case-result',
            h,
            EvaluationResultPage(
                evaluation: screenshotExample, cattleName: 'Sapi uji'));
      }
      if (mode == FarmMode.dairy) {
        await capture(
            'dairy-profile-desktop', h, CattleProfilePage(cattleId: c.id),
            width: 1280);
        await capture(
            'dairy-profile-tablet', h, CattleProfilePage(cattleId: c.id),
            width: 768);
        await capture(
            'dairy-profile-compact', h, CattleProfilePage(cattleId: c.id),
            width: 320);
        await capture(
            'dairy-profile-large-text', h, CattleProfilePage(cattleId: c.id),
            width: 390, textScale: 2);

        await capture('dairy-milk', h,
            CattleProfilePage(cattleId: c.id, initial: ProfileSection.milk));
      }
      await t.pumpWidget(const SizedBox());
      h.dispose();
    }
  });
}
