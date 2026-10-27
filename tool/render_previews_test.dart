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
        {bool app = false}) async {
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
      final evaluation = await h.evaluate(c.id);
      await capture('${mode.name}-home', h, const SapiensApp(), app: true);
      await capture(
          '${mode.name}-profile', h, CattleProfilePage(cattleId: c.id));
      await capture(
          '${mode.name}-result',
          h,
          EvaluationResultPage(
              evaluation: evaluation,
              cattleName: mode == FarmMode.beef ? 'Bima' : 'Sari'));
      if (mode == FarmMode.dairy) {
        await capture('dairy-milk', h,
            CattleProfilePage(cattleId: c.id, initial: ProfileSection.milk));
      }
      await t.pumpWidget(const SizedBox());
      h.dispose();
    }
  });
}
