import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'result_presentation.dart';

import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';

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
    return value.entries.any((e) =>
        e.key == 'not_fully_evaluable' && e.value == true ||
        containsLimited(e.value));
  }
  if (value is List) return value.any(containsLimited);
  return false;
}

class BackendValue extends StatelessWidget {
  const BackendValue(this.value, {super.key, this.limited = false});
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
    'deficit'
  };
  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return const Text('Tidak tersedia dari layanan');
    if (v is Map) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in v.entries)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fieldLabel(e.key.toString()),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: BackendValue(e.value, limited: limited))
                  ]))
      ]);
    }
    if (v is List) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (v.isEmpty) const Text('Tidak ada entri dari layanan.'),
        for (final item in v)
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: BackendValue(item, limited: limited))
      ]);
    }
    if (v is String) {
      if (v == 'not_fully_evaluable' ||
          limited && claims.contains(v.toLowerCase())) {
        return const Text('Belum dapat dievaluasi penuh');
      }
      if (v == 'penggemukan') return const Text('Penggemukan');
      if (v == 'pembibitan') return const Text('Pembibitan');
      if (v == 'primiparous') return const Text('Laktasi pertama');
      if (v == 'multiparous') return const Text('Laktasi kedua atau lebih');
      for (final stage in DairyStage.values) {
        if (v == stage.wire) return Text(stage.label);
      }
      if (v == 'beef') return const Text('Sapi Potong');
      if (v == 'dairy') return const Text('Sapi Perah');
      return Text(backendLabel(v), style: const TextStyle(height: 1.4));
    }
    if (v is bool) return Text(v ? 'Ya' : 'Tidak');
    return Text(v is num
        ? number(v.toDouble(), digits: v % 1 == 0 ? 0 : 2)
        : v.toString());
  }
}

class EvaluationResultPage extends StatelessWidget {
  const EvaluationResultPage(
      {super.key, required this.evaluation, required this.cattleName});
  final NutritionEvaluation evaluation;
  final String cattleName;
  @override
  Widget build(BuildContext context) {
    final result = FeedResultPresentation(evaluation);
    final cattle = resultMap(evaluation.request['cattle']);
    final category = evaluation.request['production_category'];
    final requirement = resultMap(evaluation.response['requirement']);
    final warnings = result.warnings;
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
                    Text(result.headline,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text(result.summary),
                    if (result.deficientCount > 0 ||
                        result.unavailable.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                          result.skippedCount > 0
                              ? 'Lihat daftar pakan di bawah untuk bahan yang belum dihitung dan alasannya.'
                              : 'Periksa apakah semua bahan dan jumlah pakan harian sudah dimasukkan.',
                          style: const TextStyle(fontWeight: FontWeight.w600))
                    ]
                  ])),
          Wrap(spacing: 16, runSpacing: 6, children: [
            if (category == 'beef' || category == 'dairy')
              Text(category == 'beef' ? 'Sapi Potong' : 'Sapi Perah'),
            if (resultNumber(cattle['body_weight_kg']) != null)
              Text(
                  'Bobot saat evaluasi: ${number(resultNumber(cattle['body_weight_kg'])!)} kg'),
          ]),
          const Heading('Perbandingan per hari'),
          const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                  'Kebutuhan dihitung untuk sapi ini. Dari pakan adalah kontribusi bahan yang berhasil dihitung oleh layanan.',
                  style: TextStyle(color: Palette.muted))),
          if (result.available.isNotEmpty)
            Surface(
                padding: 16,
                child: Column(children: [
                  for (var i = 0; i < result.available.length; i++) ...[
                    if (i > 0) const Divider(height: 32),
                    _ComparisonRow(result.available[i])
                  ]
                ])),
          if (result.unavailable.isNotEmpty)
            Surface(
                padding: 4,
                child: ExpansionTile(
                    initiallyExpanded: result.available.isEmpty,
                    title: Text(
                        '${result.unavailable.length} komponen belum dapat dinilai'),
                    subtitle: const Text(
                        'Data belum lengkap, bukan berarti kandungannya nol.'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (var i = 0; i < result.unavailable.length; i++) ...[
                        if (i > 0) const Divider(),
                        _UnavailableRow(result.unavailable[i])
                      ]
                    ])),
          if (result.comparisons.isEmpty)
            const Notice(
                'Belum ada hasil perbandingan dari layanan. Tidak ada status cukup atau kurang yang dibuat oleh aplikasi.',
                warning: true),
          const Heading('Pakan yang dimasukkan'),
          const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Jumlah di bawah adalah berat pakan segar per hari, termasuk kandungan airnya.',
                  style: TextStyle(color: Palette.muted))),
          Surface(
              padding: 16,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < result.feedInputs.length; i++) ...[
                      if (i > 0) const Divider(),
                      _FeedInput(result, result.feedInputs[i])
                    ],
                    if (result.feedInputs.isEmpty)
                      const Text(
                          'Daftar bahan tidak tersedia pada snapshot ini.')
                  ])),
          if (warnings.isNotEmpty) ...[
            const Heading('Catatan yang memengaruhi hasil'),
            for (final warning in warnings) Notice(warning, warning: true)
          ],
          const Heading('Rincian perhitungan'),
          if (requirement['requirement_summary'] != null)
            _DetailSection(
                title: 'Rincian kebutuhan sapi',
                subtitle:
                    'Angka kebutuhan dari layanan, termasuk yang belum bisa dibandingkan.',
                child: _RequirementDetails(
                    resultMap(requirement['requirement_summary']))),
          if (requirement.containsKey('assumptions') ||
              evaluation.response.containsKey('assumptions') ||
              evaluation.response.containsKey('defaults_used'))
            _DetailSection(
                title: 'Asumsi dan nilai referensi',
                subtitle: 'Data yang digunakan saat input belum tersedia.',
                child: BackendValue({
                  if (requirement.containsKey('assumptions'))
                    'assumptions': requirement['assumptions'],
                  for (final key in ['assumptions', 'defaults_used'])
                    if (evaluation.response.containsKey(key))
                      key: evaluation.response[key],
                }, limited: result.dairyLimited)),
          if (evaluation.response.containsKey('coverage') ||
              evaluation.response.containsKey('confidence') ||
              requirement.containsKey('confidence'))
            _DetailSection(
                title: 'Kelengkapan data dan keyakinan layanan',
                subtitle:
                    'Kelengkapan profil nutrisi berbeda dari persentase kebutuhan yang dipenuhi.',
                child: _CoverageDetails(evaluation.response, requirement)),
          _DetailSection(
              title: 'Data teknis backend',
              subtitle: 'Respons asli untuk pemeriksaan developer.',
              child: SelectableText(
                  const JsonEncoder.withIndent('  ')
                      .convert(evaluation.response),
                  style: const TextStyle(fontSize: 12, height: 1.5))),
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                  'Disimpan sebagai histori evaluasi. Hasil ini tidak mengubah jumlah pemberian pakan secara otomatis.',
                  style: TextStyle(fontSize: 12, color: Palette.muted))),
        ]);
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow(this.row);
  final NutrientComparison row;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(row.title, style: Theme.of(context).textTheme.titleMedium),
              Tag(row.statusLabel,
                  warning: row.deficient || row.excess || row.intake)
            ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final supply = _Amount(
              label: 'Dari pakan', value: row.supply!, unit: row.displayUnit!);
          final needed = _Amount(
              label: row.intake ? 'Perkiraan konsumsi' : 'Kebutuhan',
              value: row.requirement!,
              unit: row.displayUnit!);
          return c.maxWidth < 270 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [supply, const SizedBox(height: 12), needed])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: supply),
                  const SizedBox(width: 16),
                  Expanded(child: needed)
                ]);
        }),
        if (row.percentage != null) ...[
          const SizedBox(height: 14),
          Text(
              '${number(row.percentage!, digits: 2)}% dari ${row.intake ? 'perkiraan konsumsi' : 'kebutuhan terhitung'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ExcludeSemantics(
              child: LinearProgressIndicator(
                  value: (row.percentage! / 100).clamp(0, 1),
                  minHeight: 5,
                  color: row.deficient || row.excess || row.intake
                      ? Palette.amber
                      : Palette.ink,
                  backgroundColor: Palette.line)),
        ],
        if (row.key == 'dry_matter')
          const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                  'Bahan kering adalah bagian pakan tanpa air. Angka ini berbeda dari berat pakan segar yang dimasukkan.',
                  style: TextStyle(color: Palette.muted, fontSize: 12))),
        if (row.key == 'tdn')
          const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                  'TDN adalah indikator energi yang dipakai layanan. Angka ditampilkan dalam kg TDN per hari.',
                  style: TextStyle(color: Palette.muted, fontSize: 12))),
        if (row.intake)
          const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                  'Ini perbandingan konsumsi bahan kering, belum menjadi kesimpulan kecukupan seluruh nutrien.',
                  style: TextStyle(color: Palette.muted, fontSize: 12))),
      ]);
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, required this.unit});
  final String label, unit;
  final double value;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text.rich(
            TextSpan(children: [
              TextSpan(text: number(value, digits: 2)),
              TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Palette.muted)),
            ]),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      ]);
}

class _UnavailableRow extends StatelessWidget {
  const _UnavailableRow(this.row);
  final NutrientComparison row;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(row.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(row.explanation),
        if (row.requirement != null && row.unit != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  'Kebutuhan dari layanan: ${number(row.requirement!, digits: 2)} ${row.unit}')),
      ]);
}

class _FeedInput extends StatelessWidget {
  const _FeedInput(this.result, this.input);
  final FeedResultPresentation result;
  final Map<String, dynamic> input;
  @override
  Widget build(BuildContext context) {
    final id = input['feed_id']?.toString() ?? '';
    final rows = result.supplyItems.where((r) => r['feed_id'] == id);
    final item = rows.isEmpty ? const <String, dynamic>{} : rows.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(result.feedName(id), style: Theme.of(context).textTheme.titleMedium),
      if (resultNumber(input['as_fed_kg_day']) != null)
        Text(
            '${number(resultNumber(input['as_fed_kg_day'])!, digits: 2)} kg/hari'),
      if (item['supply_evaluable'] == false)
        const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Tag('Belum ikut dihitung', warning: true)),
    ]);
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection(
      {required this.title, required this.subtitle, required this.child});
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Surface(
      padding: 4,
      child: ExpansionTile(
          title: Text(title),
          subtitle: Text(subtitle),
          childrenPadding: const EdgeInsets.all(16),
          children: [child]));
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
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final entry in fields.entries)
          if (resultNumber(data[entry.key]) != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                    '${entry.value.$1}: ${number(resultNumber(data[entry.key])!, digits: 2)} ${entry.value.$2}')),
        const Text(
            'Sumber dan metode perhitungan tersedia pada data teknis backend.',
            style: TextStyle(color: Palette.muted, fontSize: 12)),
      ]);
}

class _CoverageDetails extends StatelessWidget {
  const _CoverageDetails(this.response, this.requirement);
  final Map<String, dynamic> response, requirement;
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
    final supply = resultMap(response['supply'] ?? response['feed_supply']);
    final groups = {
      'Data kebutuhan sapi':
          resultMap(coverage['requirement'] ?? requirement['coverage']),
      'Data nutrisi pakan':
          resultMap(coverage['feed_supply'] ?? supply['coverage']),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (requirement['confidence'] != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
                'Keyakinan perhitungan kebutuhan: ${backendLabel(requirement['confidence'].toString())}')),
      if (response['confidence'] != null) ...[
        const Text('Keyakinan hasil dari layanan'),
        BackendValue(response['confidence']),
        const SizedBox(height: 12)
      ],
      for (final group in groups.entries)
        if (group.value.isNotEmpty) ...[
          Text(group.key, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final field in group.value.entries)
            if (labels.containsKey(field.key))
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                      '${labels[field.key]}: ${field.key.endsWith('_fraction') && resultNumber(field.value) != null && resultNumber(field.value)! <= 1 ? '${number(resultNumber(field.value)! * 100, digits: 0)}% cakupan data' : backendLabel(field.value.toString())}')),
          const SizedBox(height: 12),
        ],
      const Text('Cakupan data bukan persentase kecukupan pakan.',
          style: TextStyle(color: Palette.muted, fontSize: 12))
    ]);
  }
}
