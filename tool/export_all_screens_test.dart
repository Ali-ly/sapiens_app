// Read-only design inventory: renders real widgets with synthetic in-memory data.
// Opt-in only: flutter test tool/export_all_screens_test.dart --dart-define=SCREEN_EXPORT=true
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapiens_app/api/contracts.dart';
import 'package:sapiens_app/app/app.dart';
import 'package:sapiens_app/app/theme.dart';
import 'package:sapiens_app/application/providers.dart';
import 'package:sapiens_app/application/farm_controller.dart';
import 'package:sapiens_app/data/farm_repository.dart';
import 'package:sapiens_app/data/snapshot_storage.dart';
import 'package:sapiens_app/domain/condition.dart';
import 'package:sapiens_app/domain/records.dart';
import 'package:sapiens_app/domain/value.dart';
import 'package:sapiens_app/features/care/condition_page.dart';
import 'package:sapiens_app/features/care/dairy_event_page.dart';
import 'package:sapiens_app/features/cattle/add_cattle_page.dart';
import 'package:sapiens_app/features/cattle/cattle_page.dart';
import 'package:sapiens_app/features/cattle/cattle_picker.dart';
import 'package:sapiens_app/features/cattle/edit_identity_page.dart';
import 'package:sapiens_app/features/cattle/profile_page.dart';
import 'package:sapiens_app/features/feed/catalog_page.dart';
import 'package:sapiens_app/features/feed/evaluation_page.dart';
import 'package:sapiens_app/features/feed/feed_page.dart';
import 'package:sapiens_app/features/feed/result_page.dart';
import 'package:sapiens_app/features/milk/milk_editor_page.dart';
import 'package:sapiens_app/features/settings/settings_page.dart';
import 'package:sapiens_app/features/weight/photo_picker.dart';
import 'package:sapiens_app/features/weight/weight_page.dart';
import '../test/helpers/harness.dart';

class _PhotoFixture implements PhotoPicker {
  @override
  Future<List<UploadPhoto>> pick({required bool camera}) async => [
        for (var i = 0; i < (camera ? 1 : 2); i++)
          UploadPhoto(
              name: 'synthetic-$i.png',
              bytes: base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='))
      ];
}

class _BackupPicker extends FilePicker {
  _BackupPicker(this.raw);
  final String raw;
  @override
  Future<FilePickerResult?> pickFiles(
      {String? dialogTitle,
      String? initialDirectory,
      FileType type = FileType.any,
      List<String>? allowedExtensions,
      void Function(FilePickerStatus)? onFileLoading,
      bool allowCompression = true,
      int compressionQuality = 30,
      bool allowMultiple = false,
      bool withData = false,
      bool withReadStream = false,
      bool lockParentWindow = false,
      bool readSequential = false}) async {
    final bytes = Uint8List.fromList(utf8.encode(raw));
    return FilePickerResult([
      PlatformFile(
          name: 'synthetic-backup.json', size: bytes.length, bytes: bytes)
    ]);
  }
}

class _PendingStorage implements SnapshotStorage {
  final pending = Completer<String?>();
  @override
  Future<String?> read() => pending.future;
  @override
  Future<void> write(String value) async {}
}

void main() {
  testWidgets('Export all SAPIENS routes and design states', (t) async {
    final out = Directory(const String.fromEnvironment('SCREEN_DIR',
        defaultValue: '/tmp/sapiens-all-screens'));
    await t.runAsync(() => out.create(recursive: true));
    final fontRoot = Platform.environment['FLUTTER_ROOT'] ??
        '/Users/mac/Documents/Code/Flutter/flutter';
    await t.runAsync(() async {
      for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
        final loader = FontLoader(family);
        for (final name in family == 'MaterialIcons'
            ? ['MaterialIcons-Regular.otf']
            : ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
          loader.addFont(
              File('$fontRoot/bin/cache/artifacts/material_fonts/$name')
                  .readAsBytes()
                  .then((b) => ByteData.sublistView(b)));
        }
        await loader.load();
      }
    });
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Future<void> quietFrames() async {
      await t.pump(const Duration(milliseconds: 350));
      await t.pump(const Duration(milliseconds: 350));
    }

    final inventory = <Map<String, dynamic>>[];
    GlobalKey? boundaryKey;
    var serial = 0;
    Future<void> mount(Harness h, Widget page,
        {bool app = false,
        bool settle = true,
        double width = 390,
        double textScale = 1}) async {
      await t.pumpWidget(const SizedBox());
      await t.pump();
      t.view.physicalSize = Size(width, width > 600 ? 960 : 844);
      boundaryKey = GlobalKey();
      await t.pumpWidget(UncontrolledProviderScope(
          container: h.container,
          child: RepaintBoundary(
              key: boundaryKey,
              child: app
                  ? page
                  : MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: sapiensTheme(),
                      builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              textScaler: TextScaler.linear(textScale)),
                          child: child!),
                      home: const SizedBox(),
                      initialRoute: '/preview',
                      routes: {'/preview': (_) => page}))));
      if (settle) {
        await quietFrames();
      } else {
        await t.pump(const Duration(milliseconds: 250));
      }
      expect(t.takeException(), isNull);
    }

    Future<void> shot(String name, {bool paginate = true}) async {
      final folder = '${(++serial).toString().padLeft(3, '0')}-$name';
      final dir = Directory('${out.path}/$folder');
      await t.runAsync(() => dir.create(recursive: true));
      final files = <String>[];
      Future<void> write() async {
        await t.pump(const Duration(milliseconds: 40));
        expect(t.takeException(), isNull, reason: name);
        final boundary = boundaryKey!.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final file =
            '$folder/${(files.length + 1).toString().padLeft(2, '0')}.png';
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${out.path}/$file')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        files.add(file);
      }

      await write();
      if (paginate) {
        final visited = <ScrollableState>{};
        for (var pass = 0; pass < 10; pass++) {
          final states = t
              .stateList<ScrollableState>(find.byType(Scrollable))
              .where((s) =>
                  s.position.hasContentDimensions &&
                  axisDirectionToAxis(s.axisDirection) == Axis.vertical &&
                  s.position.maxScrollExtent > 0 &&
                  !visited.contains(s))
              .toList();
          if (states.isEmpty) break;
          for (final s in states) {
            visited.add(s);
            var pages = 0;
            while (s.mounted &&
                s.position.pixels < s.position.maxScrollExtent - 1) {
              expect(++pages, lessThan(100), reason: 'Unbounded scroll: $name');
              final before = s.position.pixels;
              final next = (before + s.position.viewportDimension * .72)
                  .clamp(0.0, s.position.maxScrollExtent);
              s.position.jumpTo(next);
              await t.pump(const Duration(milliseconds: 80));
              if (s.position.pixels <= before) break;
              await write();
            }
          }
        }
      }
      // Return to the top so the next interaction starts predictably.
      for (var pass = 0; pass < 3; pass++) {
        for (final state
            in t.stateList<ScrollableState>(find.byType(Scrollable)).toList()) {
          if (axisDirectionToAxis(state.axisDirection) == Axis.vertical &&
              state.position.hasContentDimensions) {
            state.position.jumpTo(state.position.minScrollExtent);
          }
        }
        await t.pump(const Duration(milliseconds: 40));
      }
      inventory.add({
        'id': folder,
        'state': name,
        'images': files,
        'width': t.view.physicalSize.width,
        'height': t.view.physicalSize.height
      });
      // Incremental manifest survives failures and makes coverage reviewable.
      await t.runAsync(() => File('${out.path}/inventory.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(inventory)));
    }

    Future<void> tap(Finder f) async {
      if (f.evaluate().isEmpty) {
        await t.scrollUntilVisible(f, 200,
            maxScrolls: 100, scrollable: find.byType(Scrollable).first);
      }
      expect(f, findsWidgets);
      await t.ensureVisible(f.first);
      await quietFrames();
      await t.tap(f.first);
      await quietFrames();
    }

    Future<void> text(String label) => tap(find.text(label));
    Future<void> screen(String name, Harness h, Widget page,
        {bool app = false}) async {
      await mount(h, page, app: app);
      await shot(name);
    }

    final empty = Harness();
    await empty.container.read(farmProvider.future);
    await screen('onboarding-unselected', empty, const SapiensApp(), app: true);
    for (final mode in FarmMode.values) {
      await mount(empty, const SapiensApp(), app: true);
      await tap(find.byKey(ValueKey('mode-${mode.name}')));
      await shot('onboarding-${mode.name}-selected');
    }
    final pendingStorage = _PendingStorage();
    final pending = Harness(overrides: [
      repositoryProvider.overrideWithValue(FarmRepository(pendingStorage))
    ]);
    await mount(pending, const SapiensApp(), app: true, settle: false);
    await shot('account-loading', paginate: false);
    await t.pumpWidget(const SizedBox());
    pending.dispose();
    final corrupt = Harness();
    corrupt.storage.raw = '{invalid';
    await mount(corrupt, const SapiensApp(), app: true);
    await shot('account-data-error');
    await t.pumpWidget(const SizedBox());
    corrupt.dispose();

    for (final mode in FarmMode.values) {
      final prefix = mode.name;
      final h = Harness(
          overrides: [photoPickerProvider.overrideWithValue(_PhotoFixture())]);
      await h.start(mode);
      await screen('$prefix-empty-home', h, const SapiensApp(), app: true);
      await screen('$prefix-empty-cattle', h, const CattlePage());
      await screen('$prefix-empty-picker', h, const CattlePickerPage());
      await screen('$prefix-empty-feed', h, const FeedPage());
      final c0 = mode == FarmMode.beef
          ? await h.add(name: 'Bima')
          : await h.lactating();
      final id = c0.id;
      await h.controller.identity(id,
          name: mode == FarmMode.beef ? 'Bima' : 'Sari',
          userId: 'SP-001',
          ageMonths: 24,
          sex: c0.sex);
      await h.controller.addWeight(id, WeightInput(kg: 305),
          expectedWeight: h.data.find(id)!.latestWeight.id);
      if (mode == FarmMode.dairy) {
        await h.controller.dairyEvent(id,
            kind: DairyEventKind.service,
            date: '2026-10-15',
            expectedEventCount: h.data.find(id)!.events.length,
            note: 'Catatan IB uji');
        await h.controller.milk(id,
            date: '2026-10-26',
            mode: MilkMode.amPm,
            unit: MilkUnit.kg,
            am: 7,
            pm: 6);
      }
      final eval = await h.evaluate(id);
      Cattle current() => h.data.find(id)!;
      await screen('$prefix-home', h, const SapiensApp(), app: true);
      // Capture the four actual bottom-navigation destinations, keeping the shell visible.
      for (final destination in ['Ternak', 'Pakan', 'Profil']) {
        await mount(h, const SapiensApp(), app: true);
        await tap(find.descendant(
            of: find.byType(NavigationBar), matching: find.text(destination)));
        await shot('$prefix-navigation-${destination.toLowerCase()}');
      }
      await screen('$prefix-cattle-picker', h, const CattlePickerPage());
      await t.enterText(find.byType(TextField).first, 'tidak-ada');
      await quietFrames();
      await shot('$prefix-picker-no-search-result');
      await screen('$prefix-cattle-list', h, const CattlePage());
      await text('Arsip');
      await shot('$prefix-empty-archive-filter');
      if (mode == FarmMode.dairy) {
        await mount(h, const CattlePage());
        await tap(find.byType(DropdownButtonFormField<DairyStage>));
        await shot('dairy-stage-filter-menu', paginate: false);
      }
      for (final section in ProfileSection.values
          .where((s) => mode == FarmMode.dairy || s != ProfileSection.milk)) {
        await screen('$prefix-profile-${section.name}', h,
            CattleProfilePage(cattleId: id, initial: section));
      }
      await screen(
          '$prefix-edit-cattle', h, EditIdentityPage(cattle: current()));
      await t.enterText(find.byType(TextFormField).first, 'Nama draft');
      await quietFrames();
      // DraftGuard uses PopScope on a pushed route, so trigger it through a real route.
      await mount(h, const CattlePage());
      await tap(find.byTooltip('Tambah Sapi'));
      await t.enterText(find.byKey(const ValueKey('cattle-name')), 'Draft');
      await quietFrames();
      await tap(find.byType(BackButton));
      await shot('$prefix-unsaved-draft-dialog', paginate: false);
      await mount(h, const AddCattlePage());
      await shot('$prefix-add-cattle-step-1');
      await tap(find.byKey(const ValueKey('cattle-next')));
      await shot('$prefix-add-cattle-validation');
      await t.enterText(find.byKey(const ValueKey('cattle-name')), 'Sapi Baru');
      await t.enterText(find.byKey(const ValueKey('cattle-age')), '12');
      await tap(find.byKey(const ValueKey('cattle-next')));
      await shot('$prefix-add-cattle-step-2-empty');
      await t.enterText(find.byKey(const ValueKey('weight-input')), '280');
      await quietFrames();
      await shot('$prefix-add-cattle-step-2-condition');
      await t.enterText(find.byKey(const ValueKey('weight-input')), '');
      await quietFrames();
      await tap(find.byKey(const ValueKey('cattle-save')));
      await shot('$prefix-add-cattle-weight-required');
      await screen(
          '$prefix-condition-form', h, ConditionPage(cattle: current()));
      if (mode == FarmMode.dairy &&
          find.text('Data nutrisi susu').evaluate().isNotEmpty) {
        await text('Data nutrisi susu');
        await shot('dairy-condition-milk-nutrition-expanded');
      }
      await screen('$prefix-weight-manual', h, WeightPage(cattle: current()));
      await text('Simpan bobot');
      await shot('$prefix-weight-validation');
      await text('Estimasi foto');
      await shot('$prefix-weight-photo-input');
      await text('Galeri');
      await shot('$prefix-weight-photo-selected');
      h.gateway.estimate = (photos) async => WeightEstimate.parse({
            'estimated_weight_kg': 301,
            'num_valid_images': 1,
            'rejected_files': [photos.last.name],
            'prediction_spread_kg': 2
          }, photos);
      await text('Estimasi berat');
      await shot('$prefix-weight-photo-result-partial');
      await text('Kualitas estimasi');
      await shot('$prefix-weight-quality-expanded');
      await text('Kamera');
      h.gateway.estimate = (_) async => throw const FormatException(
          'Layanan estimasi tidak dapat dihubungi. Coba lagi.');
      await text('Estimasi berat');
      await shot('$prefix-weight-api-error');
      await h.controller
          .addPhotos(id, await _PhotoFixture().pick(camera: true));
      await screen('$prefix-photo-gallery', h,
          CattleProfilePage(cattleId: id, initial: ProfileSection.weight));
      final image = find.byType(Image);
      if (image.evaluate().isNotEmpty) {
        await tap(image.last);
        await shot('$prefix-gallery-photo-dialog', paginate: false);
      }
      await screen('$prefix-feed-catalog', h, const FeedCatalogPage());
      final feeds = await h.gateway.feeds(mode);
      for (final f in feeds) {
        await mount(h, const FeedCatalogPage());
        await text(f.name);
        await shot('$prefix-feed-detail-${f.id}');
      }
      await screen('$prefix-feed-form', h, FeedEvaluationPage(cattleId: id));
      await text('Konteks yang digunakan');
      await shot('$prefix-feed-context-expanded');
      await tap(find.byKey(const ValueKey('feed-rumput_gajah')));
      await shot('$prefix-feed-amount-input');
      await tap(find.byTooltip('Informasi ${feeds.first.name}'));
      await shot('$prefix-feed-information-sheet');
      await screen('$prefix-feed-result', h,
          EvaluationResultPage(evaluation: eval, cattleName: current().name));
      await text('Lihat rincian perhitungan');
      await shot('$prefix-feed-calculation-detail');
      await text('Lihat data teknis backend');
      await shot('$prefix-feed-raw-data-dialog');
      await screen('$prefix-settings', h, const SettingsPage());
      await text('Ganti Jenis Peternakan');
      await shot('$prefix-mode-reset-disabled', paginate: false);
      await t.enterText(
          find.byKey(const ValueKey('confirm-mode-text')), 'GANTI');
      await quietFrames();
      await shot('$prefix-mode-reset-confirmed', paginate: false);
      await screen('$prefix-edit-farm-account', h, const AccountEditPage());
      FilePicker.platform = _BackupPicker(h.controller.export());
      await screen('$prefix-backup-settings', h, const SettingsPage());
      await text('Pulihkan dari file JSON');
      await shot('$prefix-backup-restore-dialog', paginate: false);
      if (mode == FarmMode.dairy) {
        for (final kind in DairyEventKind.values) {
          await screen('dairy-event-${kind.name}', h,
              DairyEventPage(cattle: current(), kind: kind));
        }
        await screen('dairy-milk-total-correction', h,
            MilkEditorPage(cattle: current(), record: current().milk.last));
        await text('Pagi / Sore');
        await shot('dairy-milk-am-pm');
        await tap(find.byType(DropdownButtonFormField<MilkUnit>));
        await text('Liter — hasil pengukuran volume');
        await shot('dairy-milk-liters');
        await tap(find.byIcon(Icons.calendar_today_outlined));
        await shot('date-picker-calendar', paginate: false);
        for (final stage in DairyStage.values) {
          final other = await h.add(
              name: stage.label, condition: DairyCondition(stage: stage));
          await screen('dairy-stage-${stage.name}-summary', h,
              CattleProfilePage(cattleId: other.id));
          await screen('dairy-stage-${stage.name}-condition', h,
              ConditionPage(cattle: other));
          await screen('dairy-stage-${stage.name}-feeding', h,
              FeedEvaluationPage(cattleId: other.id));
        }
        final male = await h.add(name: 'Jantan Perah', sex: Sex.male);
        await screen(
            'dairy-male-profile', h, CattleProfilePage(cattleId: male.id));
        await screen('dairy-male-condition', h, ConditionPage(cattle: male));
        await screen('dairy-male-feeding-unsupported', h,
            FeedEvaluationPage(cattleId: male.id));
      } else {
        for (final sex in Sex.values) {
          final breeding = await h.add(
              name: 'Pembibitan ${sex.label}',
              sex: sex,
              condition: BeefCondition(
                  purpose: BeefPurpose.breeding,
                  pregnancy: sex == Sex.female ? Pregnancy.pregnant : null));
          await screen('beef-breeding-${sex.name}-profile', h,
              CattleProfilePage(cattleId: breeding.id));
          await screen('beef-breeding-${sex.name}-condition', h,
              ConditionPage(cattle: breeding));
          await screen('beef-breeding-${sex.name}-feeding-unsupported', h,
              FeedEvaluationPage(cattleId: breeding.id));
        }
      }
      await mount(h, CattleProfilePage(cattleId: id));
      await tap(find.byType(PopupMenuButton<String>));
      await shot('$prefix-profile-actions-menu', paginate: false);
      await text('Arsipkan sapi');
      await shot('$prefix-archive-confirmation', paginate: false);
      await mount(h, const CattlePage());
      await h.controller.archive(id, true);
      for (final section in ProfileSection.values
          .where((s) => mode == FarmMode.dairy || s != ProfileSection.milk)) {
        await screen('$prefix-archived-profile-${section.name}', h,
            CattleProfilePage(cattleId: id, initial: section));
      }
      await mount(h, CattleProfilePage(cattleId: id));
      await tap(find.byType(PopupMenuButton<String>));
      await text('Aktifkan kembali');
      await shot('$prefix-restore-active-dialog', paginate: false);
      await mount(h, const CattlePage());
      await text('Arsip');
      await shot('$prefix-archive-list');
      await t.pumpWidget(const SizedBox());
      h.dispose();
    }
    // Real provider states: no invented loading/error screens.
    for (final state in ['loading', 'error', 'empty']) {
      final h = Harness(overrides: [
        feedCatalogProvider(FarmMode.beef).overrideWith((ref) =>
            state == 'loading'
                ? Completer<List<FeedIngredient>>().future
                : state == 'error'
                    ? Future<List<FeedIngredient>>.error(const FormatException(
                        'Koneksi ke layanan terputus. Coba lagi.'))
                    : Future.value(<FeedIngredient>[]))
      ]);
      await h.start(FarmMode.beef);
      final c = await h.add();
      await mount(h, const FeedCatalogPage(), settle: state != 'loading');
      await shot('catalog-$state', paginate: state != 'loading');
      await mount(h, FeedEvaluationPage(cattleId: c.id),
          settle: state != 'loading');
      await shot('evaluation-$state', paginate: state != 'loading');
      await t.pumpWidget(const SizedBox());
      h.dispose();
    }
    // Additional conditional forms and asynchronous states, all through existing widgets.
    final dairy = Harness();
    await dairy.start(FarmMode.dairy);
    final lactating = await dairy.lactating();
    dairy.now = DateTime.utc(2026, 10, 28, 12);
    await screen(
        'dairy-milk-new-total', dairy, MilkEditorPage(cattle: lactating));
    await text('Simpan produksi susu');
    await shot('dairy-milk-new-validation');
    await text('Pagi / Sore');
    await shot('dairy-milk-new-am-pm');
    await tap(find.byType(DropdownButtonFormField<MilkUnit>));
    await text('Liter — hasil pengukuran volume');
    await shot('dairy-milk-new-liter');
    final fresh = await dairy.add(name: 'Fresh tanpa histori kelahiran');
    await screen('dairy-calving-first-known-parity-form', dairy,
        DairyEventPage(cattle: fresh, kind: DairyEventKind.calving));
    await screen('dairy-milk-empty-history', dairy,
        CattleProfilePage(cattleId: fresh.id, initial: ProfileSection.milk));
    final dry = await dairy.add(
        name: 'Kering kandang',
        condition: const DairyCondition(stage: DairyStage.dryFarOff));
    await screen('dairy-milk-non-lactating-disabled', dairy,
        CattleProfilePage(cattleId: dry.id, initial: ProfileSection.milk));
    await dairy.controller.dairyEvent(lactating.id,
        kind: DairyEventKind.withholding,
        date: '2026-10-28',
        until: '2026-10-30',
        note: 'Tanggal uji dicatat pengguna',
        expectedEventCount: dairy.data.find(lactating.id)!.events.length);
    await dairy.controller.dairyEvent(lactating.id,
        kind: DairyEventKind.udderObservation,
        date: '2026-10-28',
        note: 'Observasi manual uji; tanpa diagnosis',
        expectedEventCount: dairy.data.find(lactating.id)!.events.length);
    await screen(
        'dairy-care-with-recorded-health-events',
        dairy,
        CattleProfilePage(
            cattleId: lactating.id, initial: ProfileSection.care));
    await screen(
        'dairy-milk-user-recorded-withholding',
        dairy,
        CattleProfilePage(
            cattleId: lactating.id, initial: ProfileSection.milk));
    await screen('missing-cattle-profile-guard', dairy,
        const CattleProfilePage(cattleId: 'missing'));
    await screen('missing-cattle-feeding-guard', dairy,
        const FeedEvaluationPage(cattleId: 'missing'));
    await t.pumpWidget(const SizedBox());
    dairy.dispose();
    final asyncHarness = Harness(
        overrides: [photoPickerProvider.overrideWithValue(_PhotoFixture())]);
    await asyncHarness.start(FarmMode.beef);
    final ac = await asyncHarness.add();
    await mount(asyncHarness, WeightPage(cattle: ac));
    await text('Estimasi foto');
    await text('Kamera');
    final weightPending = Completer<WeightEstimate>();
    asyncHarness.gateway.estimate = (_) => weightPending.future;
    await text('Estimasi berat');
    await shot('weight-estimation-in-progress', paginate: false);
    final photos = await _PhotoFixture().pick(camera: true);
    weightPending.complete(WeightEstimate.parse({
      'estimated_weight_kg': 301,
      'num_valid_images': 1,
      'rejected_files': <String>[]
    }, photos));
    await quietFrames();
    await shot('weight-estimation-success');
    await text('Simpan bobot');
    await screen('weight-history-photo-linked', asyncHarness,
        CattleProfilePage(cattleId: ac.id, initial: ProfileSection.weight));
    final nowCattle = asyncHarness.data.find(ac.id)!;
    await mount(asyncHarness, WeightPage(cattle: nowCattle));
    await t.enterText(find.byKey(const ValueKey('weight-input')), '310');
    await quietFrames();
    asyncHarness.storage.fail = true;
    await text('Simpan bobot');
    await shot('weight-storage-save-error');
    asyncHarness.storage.fail = false;
    await mount(asyncHarness, FeedEvaluationPage(cattleId: ac.id));
    await tap(find.byKey(const ValueKey('feed-rumput_gajah')));
    await t.enterText(find.byKey(const ValueKey('amount-rumput_gajah')), '25');
    await quietFrames();
    final nutritionPending = Completer<Json>();
    asyncHarness.gateway.respond = (_) => nutritionPending.future;
    await text('Evaluasi & simpan');
    await shot('nutrition-evaluation-in-progress', paginate: false);
    nutritionPending.completeError(const FormatException(
        'Layanan evaluasi tidak dapat dihubungi. Coba lagi.'));
    await quietFrames();
    await shot('nutrition-evaluation-request-error');
    await t.pumpWidget(const SizedBox());
    asyncHarness.dispose();
    await t.pumpWidget(const SizedBox());
    empty.dispose();
  },
      skip: !const bool.fromEnvironment('SCREEN_EXPORT'),
      timeout: const Timeout(Duration(minutes: 15)));
}
