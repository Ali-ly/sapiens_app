import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/selected_image.dart';
import 'package:sapita_app/screens/cattle/cattle_estimate_result_screen.dart';
import 'package:sapita_app/screens/cattle/cattle_photo_screen.dart';
import 'package:sapita_app/services/image_service.dart';
import 'package:sapita_app/state/farm_store.dart';
import 'package:sapita_app/widgets/photo_preview.dart';

import 'helpers/test_app.dart';

const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGOMqnBkwAaYsIoOWgkA29MBIwp6820AAAAASUVORK5CYII=';
SelectedImage photo(int index) {
  final bytes = base64Decode(png);
  return SelectedImage(
      file:
          XFile.fromData(bytes, name: 'cow-$index.png', mimeType: 'image/png'),
      bytes: bytes);
}

class Gallery extends ImageService {
  @override
  Future<List<SelectedImage>> pickImages() async => List.generate(4, photo);
}

int loadedImages(WidgetTester tester) => tester
    .widgetList<RawImage>(find.byType(RawImage))
    .where((image) => image.image != null)
    .length;
Future<void> waitForImages(WidgetTester tester, int count) async {
  for (var i = 0; i < 50 && loadedImages(tester) < count; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(loadedImages(tester), count);
}

void main() {
  for (final imageCount in [1, 4]) {
    testWidgets(
        'AI result displays $imageCount read-only photo previews without a TypeError',
        (tester) async {
      final store = FarmStore(read: () async => null, write: (_) async {});
      await store.load();
      final cattle = await store.saveCattle(
          Cattle(nameOrId: 'Budi', gender: 'Jantan', ageMonths: 18));
      final images = List.generate(imageCount, photo);
      final draft = cattle.copyWith(
          estimatedWeight: 242.7,
          predictionSpread: 64.4,
          validImages: imageCount,
          latestCheckImages: images,
          images: images);
      await tester.pumpWidget(buildTestApp(
          store: store, home: CattleEstimateResultScreen(draft: draft)));
      await tester.scrollUntilVisible(find.text('Foto pengecekan'), 200,
          scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(find.text('Foto pengecekan'));
      await waitForImages(tester, imageCount);
      expect(tester.takeException(), isNull);
      expect(store.byId(cattle.id)!.estimatedWeight, isNull);
      expect(() => images.first.bytes[0] = 0, throwsUnsupportedError);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      if (kIsWeb) {
        await tester
            .runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
      }
      await tester.pump(const Duration(seconds: 4));
    });
  }

  testWidgets(
      'Four uploaded read-only photo snapshots display and can be removed',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FarmStore(read: () async => null, write: (_) async {});
    await store.load();
    final cattle = await store
        .saveCattle(Cattle(nameOrId: 'Budi', gender: 'Jantan', ageMonths: 18));
    await tester.pumpWidget(buildTestApp(
        store: store,
        home: CattlePhotoScreen(draft: cattle, imageService: Gallery())));
    await tester.ensureVisible(find.text('Galeri'));
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Foto pengecekan'));
    await waitForImages(tester, 4);
    expect(find.text('4/4 foto'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus foto 1'));
    await tester.pumpAndSettle();
    await waitForImages(tester, 3);
    expect(find.text('3/4 foto'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    // Web ImageDecoder expiry uses wall time rather than the test clock.
    if (kIsWeb) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
    }
    await tester.pump(const Duration(seconds: 4));
  });
  testWidgets('Preview reuses decode bytes until the selected photo changes',
      (tester) async {
    final first = photo(1), second = photo(2);
    Widget app(SelectedImage image) =>
        MaterialApp(home: PhotoPreview(image: image));
    await tester.pumpWidget(app(first));
    await waitForImages(tester, 1);
    final bytes =
        (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;
    expect(identical(bytes, first.bytes), isFalse);
    expect(bytes, first.bytes);
    expect(() => first.bytes[0] = 0, throwsUnsupportedError);
    await tester.pumpWidget(app(first));
    expect(
        identical(
            (tester.widget<Image>(find.byType(Image)).image as MemoryImage)
                .bytes,
            bytes),
        isTrue);
    await tester.pumpWidget(app(second));
    await waitForImages(tester, 1);
    expect(
        identical(
            (tester.widget<Image>(find.byType(Image)).image as MemoryImage)
                .bytes,
            bytes),
        isFalse);
    await tester.pumpWidget(const SizedBox());
    // Web ImageDecoder expiry uses wall time rather than the test clock.
    if (kIsWeb) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
    }
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Invalid photo data explains how to replace the file',
      (tester) async {
    final bytes = base64Decode('bm90IGFuIGltYWdl');
    final image = SelectedImage(
        file: XFile.fromData(bytes, name: 'bad.jpg'), bytes: bytes);
    await tester.pumpWidget(MaterialApp(home: PhotoPreview(image: image)));
    for (var i = 0;
        i < 50 &&
            find.textContaining('Foto tidak dapat dibuka.').evaluate().isEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.textContaining('Foto tidak dapat dibuka.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    // Web ImageDecoder expiry uses wall time rather than the test clock.
    if (kIsWeb) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
    }
    await tester.pump(const Duration(seconds: 4));
  });
}
