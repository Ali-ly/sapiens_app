import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import 'result_presentation.dart';

String backendLabel(String value) =>
    const {
      'below_predicted_intake': 'Di bawah perkiraan konsumsi layanan',
      'above_predicted_intake': 'Di atas perkiraan konsumsi layanan',
      'ok': 'Evaluasi selesai',
      'partial': 'Sebagian data tersedia',
      'insufficient_data': 'Data belum lengkap',
      'not_implemented': 'Belum didukung layanan',
      'not_fully_evaluable': 'Belum dapat dievaluasi penuh',
      'requirement_ready': 'Kebutuhan tersedia; pasokan belum lengkap',
      'sufficient': 'Cukup',
      'adequate': 'Cukup',
      'deficient': 'Kurang',
      'insufficient': 'Kurang',
      'excess': 'Berlebih',
      'excessive': 'Berlebih',
      'low': 'Rendah',
      'medium': 'Sedang',
      'high': 'Tinggi',
      'available': 'Tersedia',
      'pending': 'Belum tersedia',
      'missing': 'Belum tersedia',
    }[value] ??
    value;

String fieldLabel(String key) =>
    const {
      'purpose': 'Tujuan pemeliharaan',
      'dairy_stage': 'Fase fisiologis',
      'is_heifer': 'Dara belum pernah beranak',
      'weeks_to_calving': 'Minggu menuju kelahiran',
      'ration_ndf_pct_dm': 'NDF ransum (% bahan kering)',
      'milk_fat_pct': 'Lemak susu (%)',
      'milk_protein_pct': 'Protein susu (%)',
      'milk_lactose_pct': 'Laktosa susu (%)',
      'bcs': 'BCS manual',
      'adequacy_pct': 'Persentase kebutuhan',
      'profile_coverage_fraction': 'Cakupan profil nutrien',
      'dry_matter_intake': 'Konsumsi bahan kering',
      'ration_dm_kg_day': 'Bahan kering ransum (kg/hari)',
      'reason': 'Alasan layanan',
      'status': 'Status',
      'requirement': 'Kebutuhan',
      'supply': 'Pasokan',
      'requirement_summary': 'Ringkasan kebutuhan',
      'feed_supply': 'Pasokan pakan',
      'nutrient_supply': 'Pasokan nutrien',
      'adequacy': 'Kecukupan',
      'warnings': 'Peringatan',
      'assumptions': 'Asumsi layanan',
      'defaults_used': 'Nilai referensi yang dipakai',
      'coverage': 'Cakupan data',
      'confidence': 'Keyakinan layanan',
      'requirement_confidence': 'Keyakinan kebutuhan',
      'supply_confidence': 'Keyakinan pasokan',
      'value': 'Nilai',
      'unit': 'Satuan',
      'percent_of_requirement': 'Persentase kebutuhan',
      'percentage_of_requirement': 'Persentase kebutuhan',
      'percentage': 'Persentase',
      'ratio': 'Rasio',
      'message': 'Penjelasan layanan',
      'dry_matter': 'Bahan kering',
      'dmi': 'Konsumsi bahan kering',
      'tdn': 'Energi / TDN',
      'crude_protein': 'Protein kasar',
      'calcium': 'Kalsium',
      'phosphorus': 'Fosfor',
      'energy': 'Energi',
      'protein': 'Protein',
      'dry_matter_kg_day': 'Bahan kering (kg/hari)',
      'total_dry_matter_kg_day': 'Total bahan kering (kg/hari)',
      'total_as_fed_kg_day': 'Total pakan segar (kg/hari)',
      'predicted_dmi_kg_day': 'Perkiraan konsumsi bahan kering (kg/hari)',
      'tdn_kg_day': 'TDN (kg/hari)',
      'crude_protein_g_day': 'Protein kasar (g/hari)',
      'calcium_g_day': 'Kalsium (g/hari)',
      'phosphorus_g_day': 'Fosfor (g/hari)',
      'metabolizable_energy_mcal_day': 'Energi metabolisme (Mcal/hari)',
      'nel_total_mcal_day': 'Energi netto total (Mcal/hari)',
      'nel_maintenance_mcal_day': 'Energi pemeliharaan (Mcal/hari)',
      'nel_milk_mcal_day': 'Energi produksi susu (Mcal/hari)',
      'body_weight_kg': 'Bobot sapi (kg)',
      'target_adg_kg_day': 'Target kenaikan berat (kg/hari)',
      'milk_kg_day': 'Berat susu (kg/hari)',
      'dim': 'Hari laktasi',
      'parity_group': 'Kelompok paritas',
      'source_table_id': 'Referensi tabel kebutuhan',
      'rule_version': 'Versi aturan layanan',
      'calculation_method': 'Metode layanan',
      'interpolation_nodes': 'Titik referensi layanan',
      'tdn_fraction': 'Cakupan data TDN',
      'crude_protein_fraction': 'Cakupan data protein',
      'calcium_fraction': 'Cakupan data kalsium',
      'phosphorus_fraction': 'Cakupan data fosfor',
      'missing_fields': 'Data yang masih diperlukan',
      'production_category': 'Jenis peternakan',
      'physiological_stage': 'Fase fisiologis',
      'feed_id': 'Referensi bahan',
      'feed_results': 'Rincian bahan',
      'feeds': 'Bahan',
      'per_feed': 'Rincian per bahan',
    }[key] ??
    'Rincian tambahan layanan';

bool containsLimited(Object? value) {
  if (value is String) return value == 'not_fully_evaluable';

  if (value is Map) {
    return value.entries.any(
      (e) =>
          e.key == 'not_fully_evaluable' && e.value == true ||
          containsLimited(e.value),
    );
  }

  if (value is List) return value.any(containsLimited);

  return false;
}

String joinedNutrientNames(List<NutrientComparison> rows) {
  final names = rows.map((row) => row.title).toList();

  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} dan ${names[1]}';

  return '${names.sublist(0, names.length - 1).join(', ')}, dan ${names.last}';
}

class BackendValue extends StatelessWidget {
  const BackendValue(
    this.value, {
    super.key,
    this.limited = false,
  });

  final Object? value;
  final bool limited;

  static const claims = {
    'adequate',
    'sufficient',
    'deficient',
    'insufficient',
    'excess',
    'excessive',
    'cukup',
    'kurang',
    'surplus',
    'deficit',
  };

  @override
  Widget build(BuildContext context) {
    final v = value;

    if (v == null) {
      return const Text('Tidak tersedia dari layanan');
    }

    if (v is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in v.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fieldLabel(e.key.toString()),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: BackendValue(
                      e.value,
                      limited: limited,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    if (v is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.isEmpty) const Text('Tidak ada entri dari layanan.'),
          for (final item in v)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: BackendValue(
                item,
                limited: limited,
              ),
            ),
        ],
      );
    }

    if (v is String) {
      if (v == 'not_fully_evaluable' ||
          limited && claims.contains(v.toLowerCase())) {
        return const Text('Belum dapat dievaluasi penuh');
      }

      if (v == 'penggemukan') return const Text('Penggemukan');
      if (v == 'pembibitan') return const Text('Pembibitan');
      if (v == 'primiparous') return const Text('Laktasi pertama');
      if (v == 'multiparous') {
        return const Text('Laktasi kedua atau lebih');
      }

      for (final stage in DairyStage.values) {
        if (v == stage.wire) return Text(stage.label);
      }

      if (v == 'beef') return const Text('Sapi Potong');
      if (v == 'dairy') return const Text('Sapi Perah');

      return Text(
        backendLabel(v),
        style: const TextStyle(height: 1.4),
      );
    }

    if (v is bool) {
      return Text(v ? 'Ya' : 'Tidak');
    }

    return Text(
      v is num
          ? number(
              v.toDouble(),
              digits: v % 1 == 0 ? 0 : 2,
            )
          : v.toString(),
    );
  }
}

class EvaluationResultPage extends StatelessWidget {
  const EvaluationResultPage({
    super.key,
    required this.evaluation,
    required this.cattleName,
  });

  final NutritionEvaluation evaluation;
  final String cattleName;

  @override
  Widget build(BuildContext context) {
    final result = FeedResultPresentation(evaluation);
    final cattle = resultMap(evaluation.request['cattle']);
    final category = evaluation.request['production_category'];

    return PageFrame(
      title: 'Hasil evaluasi pakan',
      subtitle: '$cattleName · ${dateText(evaluation.createdAt)}',
      children: [
        Surface(
          color: result.skippedCount == 0 &&
                  result.available.isNotEmpty &&
                  result.unavailable.isEmpty &&
                  result.available.every((r) => r.sufficient)
              ? Palette.leaf
              : Palette.warningSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.headline,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(result.summary),
            ],
          ),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (category == 'beef' || category == 'dairy')
              Text(
                category == 'beef' ? 'Sapi Potong' : 'Sapi Perah',
                style: const TextStyle(
                  color: Palette.muted,
                ),
              ),
            if (resultNumber(cattle['body_weight_kg']) != null)
              Text(
                'Bobot ${number(resultNumber(cattle['body_weight_kg'])!)} kg',
                style: const TextStyle(
                  color: Palette.muted,
                ),
              ),
          ],
        ),
        const Heading('Perbandingan per hari'),
        if (result.available.isNotEmpty)
          Surface(
            padding: 16,
            child: Column(
              children: [
                for (var i = 0; i < result.available.length; i++) ...[
                  if (i > 0) const Divider(height: 32),
                  _ComparisonRow(result.available[i]),
                ],
              ],
            ),
          ),
        if (result.comparisons.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Belum ada komponen yang dapat dibandingkan dari hasil layanan.',
              style: TextStyle(color: Palette.muted),
            ),
          ),
        const Heading('Pakan yang dimasukkan'),
        Surface(
          padding: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < result.feedInputs.length; i++) ...[
                if (i > 0) const Divider(),
                _FeedInput(
                  result,
                  result.feedInputs[i],
                ),
              ],
              if (result.feedInputs.isEmpty)
                const Text(
                  'Daftar bahan tidak tersedia pada evaluasi ini.',
                ),
            ],
          ),
        ),
        if (result.unavailable.isNotEmpty) ...[
          const Heading('Catatan penting'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${joinedNutrientNames(result.unavailable)} belum dapat dinilai',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Data nutrisi yang tersedia belum cukup untuk menghitung komponen tersebut secara penuh. Nilai yang belum tersedia tidak berarti kandungannya nol.',
              style: TextStyle(
                color: Palette.muted,
                height: 1.5,
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _CalculationDetailPage(
                      evaluation: evaluation,
                      result: result,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 44),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                      child: Text(
                    'Lihat rincian perhitungan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  )),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Disimpan sebagai histori evaluasi.',
            style: TextStyle(
              fontSize: 12,
              color: Palette.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _CalculationDetailPage extends StatelessWidget {
  const _CalculationDetailPage({
    required this.evaluation,
    required this.result,
  });

  final NutritionEvaluation evaluation;
  final FeedResultPresentation result;

  @override
  Widget build(BuildContext context) {
    final requirement = resultMap(
      evaluation.response['requirement'],
    );

    final hasReferences = result.warnings.isNotEmpty ||
        requirement.containsKey('assumptions') ||
        evaluation.response.containsKey('assumptions') ||
        evaluation.response.containsKey('defaults_used');

    final hasCoverage = evaluation.response.containsKey('coverage') ||
        evaluation.response.containsKey('confidence') ||
        requirement.containsKey('confidence');

    return PageFrame(
      title: 'Rincian perhitungan',
      subtitle:
          'Informasi tambahan tentang bagaimana hasil evaluasi ini diperoleh.',
      children: [
        if (requirement['requirement_summary'] != null) ...[
          const Heading('Kebutuhan sapi'),
          _RequirementDetails(
            resultMap(requirement['requirement_summary']),
          ),
        ],
        if (hasReferences) ...[
          const _SectionDivider(),
          const Heading('Catatan dan referensi'),
          for (final warning in result.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('•'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          if (requirement.containsKey('assumptions') ||
              evaluation.response.containsKey('assumptions') ||
              evaluation.response.containsKey('defaults_used'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BackendValue(
                {
                  if (requirement.containsKey('assumptions'))
                    'assumptions': requirement['assumptions'],
                  for (final key in [
                    'assumptions',
                    'defaults_used',
                  ])
                    if (evaluation.response.containsKey(key))
                      key: evaluation.response[key],
                },
                limited: result.dairyLimited,
              ),
            ),
        ],
        if (hasCoverage) ...[
          const _SectionDivider(),
          const Heading('Kelengkapan data'),
          _CoverageDetails(
            evaluation.response,
            requirement,
          ),
        ],
        const _SectionDivider(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Data teknis backend'),
                    content: SizedBox(
                      width: 700,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ')
                              .convert(evaluation.response),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text('Tutup'),
                      ),
                    ],
                  );
                },
              );
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
            ),
            child: const Text(
              'Lihat data teknis backend',
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow(this.row);

  final NutrientComparison row;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                row.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Tag(
                row.statusLabel,
                warning: row.deficient || row.excess || row.intake,
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final supply = _Amount(
                label: 'Dari pakan',
                value: row.supply!,
                unit: row.displayUnit!,
              );

              final needed = _Amount(
                label: row.intake ? 'Perkiraan konsumsi' : 'Kebutuhan',
                value: row.requirement!,
                unit: row.displayUnit!,
              );

              return c.maxWidth < 270 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        supply,
                        const SizedBox(height: 12),
                        needed,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: supply),
                        const SizedBox(width: 16),
                        Expanded(child: needed),
                      ],
                    );
            },
          ),
          if (row.percentage != null) ...[
            const SizedBox(height: 14),
            Text(
              '${number(row.percentage!, digits: 2)}% dari '
              '${row.intake ? 'perkiraan konsumsi' : 'kebutuhan'}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: LinearProgressIndicator(
                value: (row.percentage! / 100).clamp(0, 1),
                minHeight: 5,
                color: row.deficient || row.excess || row.intake
                    ? Palette.amber
                    : Palette.ink,
                backgroundColor: Palette.line,
              ),
            ),
          ],
          if (row.key == 'dry_matter')
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Bahan kering adalah bagian pakan tanpa air.',
                style: TextStyle(
                  color: Palette.muted,
                  fontSize: 12,
                ),
              ),
            ),
          if (row.key == 'tdn')
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'TDN adalah indikator energi yang digunakan dalam evaluasi.',
                style: TextStyle(
                  color: Palette.muted,
                  fontSize: 12,
                ),
              ),
            ),
          if (row.intake)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Perbandingan ini belum menjadi kesimpulan kecukupan seluruh nutrien.',
                style: TextStyle(
                  color: Palette.muted,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      );
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String unit;
  final double value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Palette.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: number(
                    value,
                    digits: 2,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Palette.muted,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _FeedInput extends StatelessWidget {
  const _FeedInput(
    this.result,
    this.input,
  );

  final FeedResultPresentation result;
  final Map<String, dynamic> input;

  @override
  Widget build(BuildContext context) {
    final id = input['feed_id']?.toString() ?? '';
    final rows = result.supplyItems.where((r) => r['feed_id'] == id);

    final item = rows.isEmpty ? const <String, dynamic>{} : rows.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.feedName(id),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (resultNumber(input['as_fed_kg_day']) != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${number(resultNumber(input['as_fed_kg_day'])!, digits: 2)} kg/hari',
              style: const TextStyle(
                color: Palette.muted,
              ),
            ),
          ),
        if (item['supply_evaluable'] == false)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Tag(
              'Belum ikut dihitung',
              warning: true,
            ),
          ),
      ],
    );
  }
}

class _RequirementDetails extends StatelessWidget {
  const _RequirementDetails(this.data);

  final Map<String, dynamic> data;

  static const fields = {
    'dry_matter_kg_day': ('Bahan kering', 'kg/hari'),
    'predicted_dmi_kg_day': ('Perkiraan konsumsi bahan kering', 'kg/hari'),
    'tdn_kg_day': ('Energi (TDN)', 'kg/hari'),
    'crude_protein_g_day': ('Protein kasar', 'g/hari'),
    'calcium_g_day': ('Kalsium', 'g/hari'),
    'phosphorus_g_day': ('Fosfor', 'g/hari'),
    'metabolizable_energy_mcal_day': ('Energi metabolisme', 'Mcal/hari'),
    'energy_total_mcal_day': ('Total energi netto (NEL)', 'Mcal/hari'),
    'nel_maintenance_mcal_day': ('Energi pemeliharaan (NEL)', 'Mcal/hari'),
    'nel_milk_mcal_day': ('Energi produksi susu (NEL)', 'Mcal/hari'),
  };

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in fields.entries)
            if (resultNumber(data[entry.key]) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.value.$1,
                        style: const TextStyle(
                          color: Palette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Flexible(
                        child: Text(
                      '${number(resultNumber(data[entry.key])!, digits: 2)} ${entry.value.$2}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                  ],
                ),
              ),
        ],
      );
}

class _CoverageDetails extends StatelessWidget {
  const _CoverageDetails(
    this.response,
    this.requirement,
  );

  final Map<String, dynamic> response;
  final Map<String, dynamic> requirement;

  static const labels = {
    'dry_matter': 'Bahan kering',
    'dmi': 'Konsumsi bahan kering',
    'energy': 'Energi',
    'protein': 'Protein',
    'calcium': 'Kalsium',
    'phosphorus': 'Fosfor',
    'tdn_fraction': 'Profil energi (TDN)',
    'crude_protein_fraction': 'Profil protein kasar',
    'calcium_fraction': 'Profil kalsium',
    'phosphorus_fraction': 'Profil fosfor',
  };

  @override
  Widget build(BuildContext context) {
    final coverage = resultMap(response['coverage']);

    final supply = resultMap(
      response['supply'] ?? response['feed_supply'],
    );

    final groups = {
      'Data kebutuhan sapi': resultMap(
        coverage['requirement'] ?? requirement['coverage'],
      ),
      'Data nutrisi pakan': resultMap(
        coverage['feed_supply'] ?? supply['coverage'],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (requirement['confidence'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _DetailRow(
              label: 'Keyakinan kebutuhan',
              value: backendLabel(
                requirement['confidence'].toString(),
              ),
            ),
          ),
        if (response['confidence'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keyakinan hasil',
                  style: TextStyle(
                    color: Palette.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                BackendValue(response['confidence']),
              ],
            ),
          ),
        for (final group in groups.entries)
          if (group.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 10,
              ),
              child: Text(
                group.key,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final field in group.value.entries)
              if (labels.containsKey(field.key))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DetailRow(
                    label: labels[field.key]!,
                    value: field.key.endsWith('_fraction') &&
                            resultNumber(field.value) != null &&
                            resultNumber(field.value)! <= 1
                        ? '${number(resultNumber(field.value)! * 100, digits: 0)}%'
                        : backendLabel(
                            field.value.toString(),
                          ),
                  ),
                ),
          ],
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Kelengkapan data berbeda dari persentase kebutuhan nutrisi yang terpenuhi.',
            style: TextStyle(
              color: Palette.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Palette.muted,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
