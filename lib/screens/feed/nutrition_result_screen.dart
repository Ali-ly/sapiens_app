import 'package:flutter/material.dart';

import '../../models/feed_api_v2.dart';
import '../../models/feed_plan.dart';
import '../../models/production.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';

/// Presentation of backend JSON only. No requirement/threshold is calculated.
class NutritionResultContent extends StatelessWidget {
  const NutritionResultContent(
      {super.key, required this.response, required this.category});
  final NutritionResponse response;
  final ProductionCategory category;

  static bool notFullyEvaluable(Object? value) {
    if (value is String) {
      return value.trim().toLowerCase() == 'not_fully_evaluable';
    }
    if (value is List) return value.any(notFullyEvaluable);
    if (value is Map) {
      return value.entries.any((e) =>
          e.key == 'not_fully_evaluable' && e.value == true ||
          notFullyEvaluable(e.value));
    }
    return false;
  }

  static String label(String key) =>
      const {
        'requirement': 'Kebutuhan nutrisi',
        'supply': 'Pasokan nutrien',
        'feed_supply': 'Pasokan nutrien',
        'adequacy': 'Status evaluasi',
        'status': 'Status',
        'warnings': 'Peringatan',
        'assumptions': 'Asumsi layanan',
        'defaults_used': 'Nilai default yang digunakan',
        'coverage': 'Coverage',
        'confidence': 'Confidence',
        'confidence_score': 'Confidence score',
        'value': 'Nilai',
        'unit': 'Satuan',
      }[key] ??
      key.replaceAll('_', ' ');

  static const _claims = {
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
    'low',
    'high'
  };

  Widget value(Object? raw, {required bool limited, bool confidence = false}) {
    if (raw == null) return const Text('Tidak tersedia');
    if (raw is Map) {
      if (raw.isEmpty) return const Text('Tidak ada rincian yang dikirim.');
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final entry in raw.entries)
          if (!(limited && _statusField(entry.key.toString())))
            Padding(
                padding: const EdgeInsets.only(left: 10, top: 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label(entry.key.toString()),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      value(entry.value,
                          limited: limited,
                          confidence: confidence ||
                              entry.key
                                  .toString()
                                  .toLowerCase()
                                  .contains('confidence')),
                    ])),
      ]);
    }
    if (raw is List) {
      if (raw.isEmpty) return const Text('Tidak ada entri yang dikirim.');
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final item in raw)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: value(item, limited: limited, confidence: confidence)),
      ]);
    }
    if (raw is String && notFullyEvaluable(raw)) {
      return const Text('Belum dapat dievaluasi penuh');
    }
    if (limited &&
        raw is String &&
        _claims.contains(raw.trim().toLowerCase()) &&
        !(confidence && {'low', 'high'}.contains(raw.trim().toLowerCase()))) {
      return const Text('Belum dapat dievaluasi penuh');
    }
    return Text(raw.toString());
  }

  bool _statusField(String field) {
    final key = field.toLowerCase();
    return key.contains('adequacy') ||
        key.contains('adequate') ||
        key.contains('sufficient');
  }

  @override
  Widget build(BuildContext context) {
    final data = response.data;
    final limited =
        category == ProductionCategory.dairy && notFullyEvaluable(data);
    const sections = [
      'status',
      'requirement',
      'supply',
      'feed_supply',
      'adequacy',
      'warnings',
      'assumptions',
      'defaults_used',
      'coverage',
      'confidence',
      'confidence_score'
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (limited)
        const InfoBanner(
            'Belum dapat dievaluasi penuh. Status nutrien tidak disimpulkan dari data yang belum lengkap.',
            warning: true),
      for (final key in sections)
        if (data.containsKey(key) &&
            (!{'coverage', 'confidence', 'confidence_score'}.contains(key) ||
                data[key] != null)) ...[
          SectionHeading(label(key)),
          Panel(
              child: limited && key == 'adequacy'
                  ? const Text('Belum dapat dievaluasi penuh')
                  : value(data[key],
                      limited: limited,
                      confidence:
                          {'confidence', 'confidence_score'}.contains(key))),
        ],
      if (data.keys
          .any((k) => !sections.contains(k) && k != 'production_category')) ...[
        const SectionHeading('Informasi lain dari layanan'),
        Panel(
            child: value({
          for (final key in data.keys)
            if (!sections.contains(key) && key != 'production_category')
              key: data[key]
        }, limited: limited)),
      ],
      if (data.entries
          .every((e) => e.key == 'production_category' || e.value == null))
        const InfoBanner('Layanan tidak mengirim rincian evaluasi.',
            warning: true),
    ]);
  }
}

class NutritionResultScreen extends StatefulWidget {
  const NutritionResultScreen(
      {super.key, required this.plan, this.saved = false});
  final FeedPlan plan;
  final bool saved;
  @override
  State<NutritionResultScreen> createState() => _NutritionResultScreenState();
}

class _NutritionResultScreenState extends State<NutritionResultScreen> {
  late bool saved = widget.saved;
  bool busy = false;
  String? error;

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FarmScope.read(context).savePlan(widget.plan);
      if (mounted) setState(() => saved = true);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final plan = widget.plan;
        final store = FarmScope.read(context);
        final stale =
            plan.isNutritionEvaluation && !store.nutritionPlanMatches(plan);
        final archived = store.byId(plan.cattleId)?.isActive != true;
        return FarmPage(
            title: 'Hasil evaluasi nutrisi',
            subtitle: plan.cattleName,
            back: true,
            children: [
              Text(
                  '${plan.productionCategory!.name.toUpperCase()} · ${dateLabel(plan.createdAt.toLocal())} · ${kgLabel(plan.weightKg)} kg'),
              if (saved)
                const InfoBanner(
                    'Evaluasi tersimpan sebagai snapshot histori.'),
              if (stale || archived)
                const InfoBanner(
                    'Data sapi sudah berubah atau profil nonaktif. Hasil ini tetap menampilkan snapshot saat evaluasi.',
                    warning: true),
              const SectionHeading('Bahan yang dievaluasi'),
              if (plan.nutritionRequest == null)
                const Text(
                    'Input evaluasi v2 tidak tercatat pada snapshot lama.'),
              for (final item in plan.nutritionRequest?.feedItems ??
                  const <NutritionFeedItem>[])
                Text(
                    '${item.feedId}: ${kgLabel(item.asFedKgDay)} kg/ekor/hari (pakan segar)'),
              NutritionResultContent(
                  response: plan.nutritionSnapshot!.response,
                  category: plan.productionCategory!),
              const SizedBox(height: 20),
              const InfoBanner(
                  'Menyimpan evaluasi tidak otomatis menjadikannya ransum aktif atau kebutuhan stok.'),
              if (error != null) InfoBanner(error!, warning: true),
              if (!saved)
                FilledButton(
                    onPressed: busy || stale || archived ? null : save,
                    child: Text(busy ? 'Menyimpan…' : 'Simpan evaluasi')),
              if (saved)
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Selesai')),
            ]);
      });
}
