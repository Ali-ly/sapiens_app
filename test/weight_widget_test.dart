import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapiens_app/api/contracts.dart';
import 'package:sapiens_app/application/farm_controller.dart';
import 'package:sapiens_app/app/theme.dart';
import 'package:sapiens_app/features/weight/photo_picker.dart';
import 'package:sapiens_app/features/weight/weight_entry.dart';
import 'package:sapiens_app/ui/components.dart';
import 'helpers/harness.dart';

class TestPicker implements PhotoPicker {
  final calls = <bool>[];
  @override
  Future<List<UploadPhoto>> pick({required bool camera}) async {
    calls.add(camera);
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
    return [
      for (var i = 0; i < (camera ? 1 : 2); i++)
        UploadPhoto(name: 'photo-$i.png', bytes: bytes)
    ];
  }
}

void main() {
  testWidgets(
      'Gallery partial rejection labels the excluded photo; camera repick clears previous result',
      (t) async {
    final picker = TestPicker();
    final h =
        Harness(overrides: [photoPickerProvider.overrideWithValue(picker)]);
    final container = h.container;
    addTearDown(h.dispose);
    WeightInput? current;
    h.gateway.estimate = (photos) async => WeightEstimate.parse({
          'estimated_weight_kg': 301,
          'num_valid_images': 1,
          'rejected_files': photos.length == 2 ? [photos.last.name] : [],
        }, photos);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: sapiensTheme(),
            home: PageFrame(
                title: 'Bobot',
                children: [WeightEntry(onChanged: (v) => current = v)]))));
    Future<void> tap(String text) async {
      final finder = find.text(text);
      await t.scrollUntilVisible(finder, 100,
          scrollable: find.byType(Scrollable).first);
      await t.tap(finder);
      await t.pumpAndSettle();
    }

    await tap('Estimasi foto');
    await tap('Galeri');
    expect(current, isNull);
    await tap('Estimasi berat');
    expect(current!.kg, 301);
    expect(current!.photos, hasLength(1));
    expect(find.text('Foto 2 tidak dipakai'), findsOneWidget);
    await tap('Kamera');
    expect(picker.calls, [false, true]);
    expect(current, isNull);
    expect(find.text('301 kg'), findsNothing);
    await tap('Estimasi berat');
    expect(current!.photos, hasLength(1));
    expect(h.gateway.weightCalls, 2);
    expect(t.takeException(), isNull);
  });
}
