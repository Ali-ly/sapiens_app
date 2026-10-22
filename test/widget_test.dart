import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cattle_app/app.dart';
import 'package:cattle_app/models/cattle_draft.dart';
import 'package:cattle_app/state/farm_store.dart';

void main() {
  late FarmStore store;
  late String? saved;
  setUp(() async {
    saved = null;
    store = FarmStore(
      read: () async => saved,
      write: (value) async {
        saved = value;
      },
    );
    FarmStore.instance = store;
    await store.load();
  });
  test('Create, rename, weight history, persistence and deletion', () async {
    final c = await store.save(
      const CattleDraft(
        nameOrId: 'B006 - Raka',
        gender: 'Jantan',
        ageMonths: 18,
      ),
    );
    expect(c.id, isNotEmpty);
    expect(store.needsCheck(c), isTrue);
    final updated = await store.save(
      c.copyWith(
        nameOrId: 'Raka',
        estimatedWeight: 300,
        history: [WeightRecord(weightKg: 300, date: DateTime.now())],
      ),
    );
    expect(store.cattle.length, 1);
    expect(store.needsCheck(updated), isFalse);
    final reloaded = FarmStore(read: () async => saved, write: (_) async {});
    await reloaded.load();
    expect(reloaded.cattle.single.nameOrId, 'Raka');
    expect(reloaded.cattle.single.history.single.weightKg, 300);
    await store.remove(c.id);
    expect(store.cattle, isEmpty);
  });
  test('Failed storage does not report a successful save', () async {
    final broken = FarmStore(
      read: () async => null,
      write: (_) async => throw Exception('disk full'),
    );
    await broken.load();
    await expectLater(
      broken.save(
        const CattleDraft(nameOrId: 'A', gender: 'Jantan', ageMonths: 12),
      ),
      throwsException,
    );
    expect(broken.cattle, isEmpty);
  });
  test('Duplicate IDs and corrupt storage are protected', () async {
    await store.save(
      const CattleDraft(nameOrId: 'Raka', gender: 'Jantan', ageMonths: 18),
    );
    await expectLater(
      store.save(
        const CattleDraft(nameOrId: 'raka', gender: 'Betina', ageMonths: 20),
      ),
      throwsStateError,
    );
    final broken = FarmStore(
      read: () async => 'broken json',
      write: (_) async => fail('must not overwrite unreadable data'),
    );
    await broken.load();
    expect(broken.error, isNotNull);
    await expectLater(broken.addExamples(), throwsStateError);
  });
  test('Concurrent writes retain both cattle and settings persist', () async {
    await Future.wait([
      store.save(
          const CattleDraft(nameOrId: 'A', gender: 'Jantan', ageMonths: 12)),
      store.save(
          const CattleDraft(nameOrId: 'B', gender: 'Betina', ageMonths: 24)),
    ]);
    expect(store.cattle.length, 2);
    await store.settings('Dewi', 'Kandang Sejahtera', 14);
    final reloaded = FarmStore(read: () async => saved, write: (_) async {});
    await reloaded.load();
    expect(reloaded.farmer, 'Dewi');
    expect(reloaded.farm, 'Kandang Sejahtera');
    expect(reloaded.reminderDays, 14);
    expect(reloaded.cattle.length, 2);
  });
  testWidgets('Navigate, create, search and record a weight at mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SapitaApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Belum ada sapi'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Belum ada sapi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tambah sapi'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Tambah sapi'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nama / ID sapi'),
      'B006 - Raka',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Umur (bulan)'),
      '18',
    );
    await tester.ensureVisible(find.text('Simpan sapi'));
    await tester.tap(find.text('Simpan sapi'));
    await tester.pumpAndSettle();
    expect(store.cattle.length, 1);
    expect(find.text('Catat bobot manual'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sapi').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Raka');
    await tester.pumpAndSettle();
    await tester.tap(find.text('B006 - Raka'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Catat bobot manual'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Catat bobot manual'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bobot (kg)'),
      '330,5',
    );
    await tester.tap(find.text('Simpan bobot'));
    await tester.pumpAndSettle();
    expect(store.cattle.single.estimatedWeight, 330.5);
    expect(tester.takeException(), isNull);
  });
}
