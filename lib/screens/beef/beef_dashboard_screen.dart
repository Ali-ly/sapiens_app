import 'package:flutter/material.dart';

import '../../models/beef/beef_growth.dart';
import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../cattle/cattle_profile_screen.dart';
import 'beef_module_screen.dart';
import 'feed_stock_screen.dart';

class BeefDashboardScreen extends StatefulWidget {
  const BeefDashboardScreen({super.key});
  @override
  State<BeefDashboardScreen> createState() => _BeefDashboardScreenState();
}

class _BeefDashboardScreenState extends State<BeefDashboardScreen> {
  bool inactive = false;
  BeefPurpose? purpose;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final store = FarmScope.read(context), active = store.activeBeef;
        final rows = store.allCattle
            .where((c) =>
                c.productionCategory == ProductionCategory.beef &&
                c.isActive != inactive &&
                (purpose == null || c.modules.beef?.purpose == purpose))
            .toList();
        final evaluate = active
            .where((c) =>
                c.modules.beef?.purpose == BeefPurpose.fattening &&
                !store.needsCheck(c) &&
                BeefGrowth(c, store.currentTime).harvest ==
                    HarvestState.evaluate)
            .length;
        return FarmPage(
            title: 'Ringkasan Beef',
            subtitle:
                '${active.length} aktif · $evaluate mencapai target pengguna',
            back: true,
            children: [
              const InfoBanner(
                  'Hanya kategori Beef. Statistik memakai sapi aktif; daftar nonaktif mempertahankan histori tanpa menambah hitungan operasional.'),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: const Text('Aktif'),
                    selected: !inactive,
                    onSelected: (_) => setState(() => inactive = false)),
                ChoiceChip(
                    label: const Text('Nonaktif'),
                    selected: inactive,
                    onSelected: (_) => setState(() => inactive = true))
              ]),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: const Text('Semua tujuan'),
                    selected: purpose == null,
                    onSelected: (_) => setState(() => purpose = null)),
                for (final p in BeefPurpose.values)
                  ChoiceChip(
                      label: Text(beefPurposeLabels[p]!),
                      selected: purpose == p,
                      onSelected: (_) => setState(() => purpose = p))
              ]),
              TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const FeedStockScreen())),
                  child: const Text('Stok & kebutuhan Beef')),
              if (rows.isEmpty) const Text('Tidak ada sapi untuk filter ini.'),
              for (final c in rows)
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(c.nameOrId,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      Text(
                          '${beefPurposeLabels[c.modules.beef?.purpose] ?? 'Tujuan belum dipilih'} · ${beefPhaseLabels[c.modules.beef?.phase] ?? 'Fase belum dicatat'} · ${c.status.label}'),
                      Wrap(spacing: 8, children: [
                        TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        CattleProfileScreen(cattle: c))),
                            child: const Text('Profil')),
                        TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        BeefModuleScreen(cattleId: c.id))),
                            child: const Text('Modul Beef'))
                      ])
                    ])),
            ]);
      });
}
