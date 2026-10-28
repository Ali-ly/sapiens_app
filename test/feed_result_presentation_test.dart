import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapiens_app/app/theme.dart';
import 'package:sapiens_app/domain/records.dart';
import 'package:sapiens_app/domain/value.dart';
import 'package:sapiens_app/features/feed/result_page.dart';
import 'package:sapiens_app/features/feed/result_presentation.dart';
import 'helpers/live_fixtures.dart';

NutritionEvaluation resultFixture({bool dairy = false, Json? response}) =>
    NutritionEvaluation(
        id: 'result-ui-test',
        createdAt: DateTime.utc(2026, 10, 27),
        contextHash: 'ui-only',
        contextSnapshot: const {},
        request: {
          'production_category': dairy ? 'dairy' : 'beef',
          'cattle': {'body_weight_kg': dairy ? 500 : 300},
          'feed_items': [
            {'feed_id': 'rumput_gajah', 'as_fed_kg_day': dairy ? 30 : 25},
            {'feed_id': 'dedak_padi_bekatul', 'as_fed_kg_day': dairy ? 4 : 3}
          ]
        },
        response: response ?? (dairy ? dairyResponse() : beefResponse()),
        feedNames: const {
          'rumput_gajah': 'Rumput gajah',
          'dedak_padi_bekatul': 'Dedak/Bekatul'
        });

void main() {
  test('Backend ok means successful evaluation, not sufficient nutrition', () {
    final response = beefResponse();
    response['feed_supply']['items'] = [response['feed_supply']['items'][0]];
    final p = FeedResultPresentation(resultFixture(response: response));
    expect(p.headline, 'Pakan yang dihitung masih kurang');
    expect(p.deficientCount, 3);
    expect(p.unavailable.length, 2);
    expect(p.available.first.supply, 5.08);
    expect(p.available.first.requirement, 7);
    expect(p.available.first.unit, 'kg/hari');
  });
  test('Unknown mineral supply zeros never become a zero-content claim', () {
    final p = FeedResultPresentation(resultFixture());
    final calcium = p.unavailable.firstWhere((r) => r.key == 'calcium');
    expect(calcium.supply, 0);
    expect(calcium.comparable, false);
    expect(calcium.statusLabel, 'Belum dapat dinilai');
    expect(calcium.explanation, contains('angka nol tidak berarti'));
  });
  test(
      'Dairy partial only compares intake and never labels nutrients enough/deficient',
      () {
    final raw = dairyResponse();
    raw['adequacy']['energy'] = {
      'status': 'adequate',
      'supply': 20,
      'requirement': 19,
      'unit': 'Mcal/day'
    };
    final p = FeedResultPresentation(resultFixture(dairy: true, response: raw));
    expect(p.headline, 'Belum dapat dievaluasi penuh');
    expect(p.available.single.key, 'dry_matter_intake');
    expect(p.available.single.statusLabel, 'Di bawah perkiraan konsumsi');
    expect(p.deficientCount, 0);
    expect(p.unavailable.any((r) => r.key == 'energy'), isTrue);
  });
  test(
      'Coverage, missing values and unknown units cannot produce confident claims',
      () {
    for (final row in [
      {
        'status': 'deficient',
        'requirement': 10,
        'supply': 5,
        'unit': 'kg/day',
        'profile_coverage_fraction': .5
      },
      {'status': 'adequate', 'requirement': 10, 'unit': 'kg/day'},
      {
        'status': 'adequate',
        'requirement': 10,
        'supply': 20,
        'unit': 'future_unit'
      },
      {
        'status': 'future_status',
        'requirement': 10,
        'supply': 20,
        'unit': 'kg/day'
      },
    ]) {
      expect(NutrientComparison('energy', row, dairyLimited: false).comparable,
          isFalse);
    }
  });
  test('Warnings explain skipped feeds without losing original snapshot', () {
    final e = resultFixture(), before = e.toJson();
    final p = FeedResultPresentation(e);
    expect(
        p.warnings.any((w) => w.contains('Dedak/Bekatul belum ikut dihitung')),
        isTrue);
    expect(p.warnings.any((w) => w.contains('dry_matter_pct_as_fed')), isFalse);
    expect(p.warnings.any((w) => w.startsWith('tdn diperkirakan')), isFalse);
    expect(e.toJson(), before);
  });
  test(
      'Missing adequacy and scalar metadata do not invent nutrients or outcomes',
      () {
    final p = FeedResultPresentation(resultFixture(response: {
      'status': 'ok',
      'adequacy': {
        'status': 'ok',
        'metadata': {'count': 2}
      }
    }));
    expect(p.comparisons, isEmpty);
    expect(p.headline, 'Hasil belum dapat disimpulkan');
  });
  test(
      'Display preserves supplied percentage instead of recomputing rounded values',
      () {
    final r = NutrientComparison(
        'dry_matter',
        {
          'requirement': 5.60,
          'supply': .41,
          'adequacy_pct': 7.26,
          'profile_coverage_fraction': 1,
          'status': 'deficient',
          'unit': 'kg/day'
        },
        dairyLimited: false);
    expect(r.percentage, 7.26);
    expect(r.displayUnit, 'kg BK/hari');
  });
  test(
      'A fully evaluable true zero remains zero and is not hidden as missing data',
      () {
    final r = NutrientComparison(
        'calcium',
        {
          'requirement': 19,
          'supply': 0,
          'adequacy_pct': 0,
          'profile_coverage_fraction': 1,
          'status': 'deficient',
          'unit': 'g/day'
        },
        dairyLimited: false);
    expect(r.comparable, isTrue);
    expect(r.supply, 0);
    expect(r.deficient, isTrue);
  });
  test('Unsupported responses are distinct from nutrient deficiencies', () {
    final p = FeedResultPresentation(
        resultFixture(response: {'status': 'not_implemented'}));
    expect(p.headline, 'Konteks ini belum didukung layanan');
    expect(p.deficientCount, 0);
  });
  testWidgets('Coverage explains data completeness separately from adequacy',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: sapiensTheme(),
        home: EvaluationResultPage(
            evaluation: resultFixture(), cattleName: 'Sapi uji')));
    await t.pumpAndSettle();
    final label = find.text('Lihat rincian perhitungan');
    await t.scrollUntilVisible(label, 200, maxScrolls: 60);
    await t.ensureVisible(label);
    await t.pumpAndSettle();
    await t.tap(label);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Kelengkapan data'), 200,
        maxScrolls: 100);
    await t.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);
    expect(
        find.text(
            'Kelengkapan data berbeda dari persentase kebutuhan nutrisi yang terpenuhi.'),
        findsOneWidget);
    expect(find.text('Sedang'), findsWidgets);
  });
  for (final dairy in [false, true]) {
    for (final width in [320.0, 390.0, 1280.0]) {
      testWidgets(
          '${dairy ? 'Dairy' : 'Beef'} readable result at $width including 200% text',
          (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        for (final scale in [1.0, 2.0]) {
          await t.pumpWidget(MaterialApp(
              key: ValueKey(scale),
              theme: sapiensTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: EvaluationResultPage(
                  evaluation: resultFixture(dairy: dairy),
                  cattleName: 'Sapi uji')));
          await t.pumpAndSettle();
          expect(find.text('Tersedia'), findsNothing);
          expect(find.text('Cakupan profil nutrien'), findsNothing);
          if (dairy) {
            expect(find.text('Kurang'), findsNothing);
            expect(find.text('Cukup'), findsNothing);
          }
          for (final label in [
            'Pakan yang dimasukkan',
            'Lihat rincian perhitungan'
          ]) {
            await t.scrollUntilVisible(find.text(label), 200, maxScrolls: 60);
            await t.pumpAndSettle();
          }
          await t.ensureVisible(find.text('Lihat rincian perhitungan'));
          await t.tap(find.text('Lihat rincian perhitungan'));
          await t.pumpAndSettle();
          await t.scrollUntilVisible(
              find.text('Lihat data teknis backend'), 200,
              maxScrolls: 100);
          await t.ensureVisible(find.text('Lihat data teknis backend'));
          await t.pumpAndSettle();
          await t.tap(find.text('Lihat data teknis backend'));
          await t.pumpAndSettle();
          expect(find.byType(SelectableText), findsOneWidget);
          expect(t.takeException(), isNull);
        }
      });
    }
  }
}
