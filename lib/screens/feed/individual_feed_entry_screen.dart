import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../state/farm_store.dart';
import '../../widgets/farm_ui.dart';
import '../profile/farm_settings_screen.dart';
import 'feed_calculator_screen.dart';
import 'widgets/feed_domain_choice.dart';

/// Domain choice belongs to the individual feed journey, not to API inputs.
class IndividualFeedEntryScreen extends StatefulWidget {
  const IndividualFeedEntryScreen(
      {super.key,
      this.cattleId,
      this.initialCategory,
      this.loadFeeds,
      this.evaluate,
      this.now});
  final String? cattleId;
  final ProductionCategory? initialCategory;
  final FeedCatalogLoader? loadFeeds;
  final NutritionEvaluation? evaluate;
  final DateTime Function()? now;

  @override
  State<IndividualFeedEntryScreen> createState() =>
      _IndividualFeedEntryScreenState();
}

class _IndividualFeedEntryScreenState extends State<IndividualFeedEntryScreen> {
  late final FarmStore store;
  FarmProductionSystems? observedSystems;
  ProductionCategory? choice;

  @override
  void initState() {
    super.initState();
    store = FarmScope.read(context);
    observedSystems = store.productionSystems;
    if (observedSystems == FarmProductionSystems.both) {
      choice = widget.initialCategory;
    }
    store.addListener(farmChanged);
  }

  void farmChanged() {
    if (!mounted) return;
    setState(() {
      if (observedSystems != store.productionSystems) {
        observedSystems = store.productionSystems;
        choice = null;
      }
    });
  }

  @override
  void dispose() {
    store.removeListener(farmChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final systems = store.productionSystems;
    if (systems == null) {
      return FarmPage(
          title: 'Pakan individual',
          subtitle: 'Tentukan konteks peternakan sebelum mulai.',
          back: true,
          children: [
            const InfoBanner(
                'Sistem produksi peternakan belum dipilih. Pilih Pedaging, Perah, atau Both di pengaturan. Kategori sapi lama tidak akan ditebak.',
                warning: true),
            FilledButton(
                onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const FarmSettingsScreen())),
                child: const Text('Atur sistem produksi')),
          ]);
    }
    final category = systems.singleCategory ?? choice;
    if (category != null) {
      final candidate = store.byId(widget.cattleId ?? '');
      return FeedCalculatorScreen(
          key: ValueKey('individual-feed-${systems.name}-${category.name}'),
          productionCategory: category,
          cattleId: candidate?.productionCategory == category
              ? widget.cattleId
              : null,
          onChangeDomain: systems == FarmProductionSystems.both &&
                  widget.initialCategory == null
              ? () => setState(() => choice = null)
              : null,
          loadFeeds: widget.loadFeeds,
          evaluate: widget.evaluate,
          now: widget.now);
    }
    return FarmPage(
        title: 'Pakan untuk sapi yang mana?',
        subtitle: 'Pilih jenis sapi untuk melanjutkan.',
        back: true,
        children: [
          const Text(
              'Pakan pedaging dan perah dipisahkan agar pilihan sapi dan pencatatannya lebih mudah.'),
          const SizedBox(height: 20),
          FeedDomainChoice(
              beefCount: store.activeBeef.length,
              dairyCount: store.activeDairy.length,
              keyPrefix: 'feed-domain',
              onSelected: (domain) => setState(() => choice = domain)),
          const SizedBox(height: 16),
          const Text(
              'Sapi yang belum diklasifikasikan tidak masuk ke kedua daftar. Tentukan kategorinya melalui profil ternak.'),
        ]);
  }
}
