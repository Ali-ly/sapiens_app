import 'package:flutter/material.dart';

import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';

String backendLabel(String value) =>
    const {
      'below_predicted_intake': 'Di bawah perkiraan konsumsi layanan',
      'above_predicted_intake': 'Di atas perkiraan konsumsi layanan',
      'ok': 'Tersedia',
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
    final j = evaluation.response;
    final limited = evaluation.request['production_category'] == 'dairy' &&
        containsLimited(j);
    final status = j['status']?.toString();
    final req = j['requirement'], supply = j['supply'] ?? j['feed_supply'];
    return PageFrame(
        title: 'Hasil evaluasi pakan',
        subtitle: '$cattleName · ${dateText(evaluation.createdAt)}',
        children: [
          Tag(status == null ? 'Hasil tersimpan' : backendLabel(status),
              warning: limited || status != null && status != 'ok'),
          const SizedBox(height: 16),
          const Notice(
              'Evaluasi ini disimpan sebagai histori dari input saat itu. Bukan ransum otomatis dan bukan keputusan pemberian pakan.'),
          if (limited)
            const Notice(
                'Belum dapat dievaluasi penuh. Nutrien tidak diberi kesimpulan cukup/kurang ketika layanan belum dapat menilainya.',
                warning: true),
          if (j.containsKey('adequacy')) ...[
            const Heading('Kebutuhan dibanding pasokan'),
            Surface(child: BackendValue(j['adequacy'], limited: limited))
          ],
          if (req != null) ...[
            const Heading('Kebutuhan nutrisi'),
            Surface(
                child: BackendValue(
                    req is Map ? req['requirement_summary'] ?? req : req,
                    limited: limited)),
            if (req is Map)
              ExpansionTile(
                  title: const Text('Asumsi, sumber & keyakinan kebutuhan'),
                  children: [
                    BackendValue({
                      for (final e in req.entries)
                        if (e.key != 'requirement_summary') e.key: e.value
                    }, limited: limited)
                  ])
          ],
          if (supply != null) ...[
            const Heading('Pasokan dari pakan'),
            Surface(
                child: BackendValue(
                    supply is Map
                        ? {
                            for (final key in [
                              'total_as_fed_kg_day',
                              'total_dry_matter_kg_day',
                              'nutrient_supply'
                            ])
                              if (supply.containsKey(key)) key: supply[key]
                          }
                        : supply,
                    limited: limited)),
            if (supply is Map)
              ExpansionTile(
                  title: const Text('Rincian dan cakupan pasokan'),
                  children: [
                    BackendValue({
                      for (final e in supply.entries)
                        if (![
                          'total_as_fed_kg_day',
                          'total_dry_matter_kg_day',
                          'nutrient_supply'
                        ].contains(e.key))
                          e.key: e.value
                    }, limited: limited)
                  ])
          ],
          if (j.containsKey('warnings')) ...[
            const Heading('Peringatan layanan'),
            Surface(child: BackendValue(j['warnings'], limited: limited))
          ],
          if (j.containsKey('message'))
            Notice(j['message'].toString(), warning: true),
          for (final key in [
            'assumptions',
            'defaults_used',
            'coverage',
            'confidence',
            'missing_fields',
            'rule_version'
          ])
            if (j.containsKey(key))
              Surface(
                  padding: 8,
                  child: ExpansionTile(
                      title: Text(fieldLabel(key)),
                      childrenPadding: const EdgeInsets.all(12),
                      children: [BackendValue(j[key], limited: limited)])),
          Surface(
              padding: 8,
              child: ExpansionTile(
                  title: const Text('Input bahan saat evaluasi'),
                  children: [
                    for (final item
                        in (evaluation.request['feed_items'] as List))
                      ListTile(
                          title: Text(
                              evaluation.feedNames[(item as Map)['feed_id']] ??
                                  'Bahan pakan'),
                          subtitle: Text('${item['as_fed_kg_day']} kg/hari'))
                  ])),
        ]);
  }
}
