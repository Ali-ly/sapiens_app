import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/production.dart';
import '../../state/farm_scope.dart';
import '../../state/farm_store.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/livestock_labels.dart';
import '../beef/feed_stock_screen.dart';
import '../cattle/add_cattle_screen.dart';
import '../dairy/dairy_dashboard_screen.dart';
import '../groups/group_list_screen.dart';
import '../profile/farm_settings_screen.dart';
import 'feed_calculator_screen.dart' show FeedCatalogLoader;
import 'feed_result_screen.dart';
import 'feed_shopping_screen.dart';
import 'individual_feed_entry_screen.dart';
import 'widgets/feed_domain_choice.dart';

class FeedHubScreen extends StatefulWidget {
  const FeedHubScreen({super.key, this.loadFeeds});
  final FeedCatalogLoader? loadFeeds;
  @override
  State<FeedHubScreen> createState() => _FeedHubScreenState();
}

class _FeedHubScreenState extends State<FeedHubScreen> {
  late final FarmStore store;
  FarmProductionSystems? observedSystems;
  ProductionCategory? choice;

  @override
  void initState() {
    super.initState();
    store = FarmScope.read(context);
    observedSystems = store.productionSystems;
    store.addListener(farmChanged);
  }

  void farmChanged() {
    if (observedSystems != store.productionSystems && mounted) {
      setState(() {
        observedSystems = store.productionSystems;
        choice = null;
      });
    }
  }

  @override
  void dispose() {
    store.removeListener(farmChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: FarmScope.read(context),
        builder: (context, _) {
          final store = FarmScope.read(context);
          final systems = store.productionSystems;
          final category = systems?.singleCategory ?? choice;
          final cattle = store.cattle
              .where(
                  (c) => category != null && c.productionCategory == category)
              .toList();
          final evaluated = cattle.where((c) {
            final plan = store.latestPlan(c.id);
            return plan?.isNutritionEvaluation == true &&
                plan?.productionCategory == category;
          }).length;
          return FarmPage(
            title: 'Pakan untuk sapimu.',
            subtitle: 'Pilih sapi, catat pakan, lalu tinjau hasilnya.',
            eyebrow: 'NUTRISI & RENCANA HARIAN',
            action: IconButton(
              tooltip: 'Daftar kebutuhan pakan',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const FeedShoppingScreen()),
              ),
              icon: const Icon(CupertinoIcons.bag),
            ),
            children: [
              if (systems == null) ...[
                const InfoBanner(
                    'Pilih sistem produksi peternakan sebelum memulai pakan individual.',
                    warning: true),
                FilledButton(
                    onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const FarmSettingsScreen())),
                    child: const Text('Atur sistem produksi')),
              ],
              if (systems == FarmProductionSystems.both &&
                  category == null) ...[
                const SectionHeading('Pakan individual'),
                const Text(
                    'Pilih jenis sapi terlebih dahulu. Daftar sapi dan alur pakan akan mengikuti pilihanmu.'),
                const SizedBox(height: 16),
                FeedDomainChoice(
                    beefCount: store.activeBeef.length,
                    dairyCount: store.activeDairy.length,
                    keyPrefix: 'feed-hub-domain',
                    onSelected: (domain) => setState(() => choice = domain)),
              ],
              if (category != null) ...[
                Text(category == ProductionCategory.beef
                    ? 'Konteks Pedaging · Beef'
                    : 'Konteks Perah · Dairy'),
                if (systems == FarmProductionSystems.both)
                  TextButton(
                      onPressed: () => setState(() => choice = null),
                      child: const Text('Ganti jenis sapi')),
                Panel(
                  color: AppColors.primaryDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          StatusPill('EVALUASI PAKAN', dark: true),
                          Spacer(),
                          Icon(
                            Icons.grass_rounded,
                            color: AppColors.accent,
                            size: 32,
                          )
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$evaluated dari ${cattle.length} sapi',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'memiliki evaluasi pakan tersimpan',
                        style: TextStyle(
                          color: Color(0xFFBBC9B7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.primaryDark,
                          ),
                          onPressed: cattle.isEmpty
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const AddCattleScreen()),
                                  )
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            IndividualFeedEntryScreen(
                                                initialCategory: category,
                                                loadFeeds: widget.loadFeeds)),
                                  ),
                          icon: const Icon(CupertinoIcons.add, size: 18),
                          label: Text(
                            cattle.isEmpty
                                ? 'Tambahkan sapi pertama'
                                : 'Hitung kebutuhan pakan',
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                const SectionHeading('Rencana per sapi'),
                if (cattle.isEmpty)
                  const EmptyPanel(
                    title: 'Mulai dari sapimu',
                    message:
                        'Daftarkan sapi dan catat bobotnya. Kami akan memakai bobot tersebut untuk menghitung kebutuhan pakan.',
                  ),
                ...cattle.map(
                  (c) {
                    final plan = store.latestPlan(c.id);
                    final active = store.planReady(c);
                    final evaluation = plan?.isNutritionEvaluation == true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CattleAvatar(cattle: c, size: 48),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.nameOrId,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        c.estimatedWeight == null
                                            ? 'Belum ada bobot'
                                            : '${kgLabel(c.estimatedWeight!)} kg · ${ageEvidenceLabel(c)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                StatusPill(
                                  evaluation
                                      ? 'Evaluasi tersimpan'
                                      : active
                                          ? 'Siap'
                                          : plan == null
                                              ? 'Belum dihitung'
                                              : 'Perlu ditinjau',
                                  warning: !active && !evaluation,
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (plan != null) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      evaluation
                                          ? 'Input bahan evaluasi / hari'
                                          : 'Pakan segar / hari',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${kgLabel(plan.totalFreshKg)} kg',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (evaluation)
                                const Text(
                                    'Snapshot evaluasi; bukan ransum aktif atau kebutuhan stok.'),
                              if (!active && !evaluation)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Bobot perlu dicek atau data sapi telah berubah. Tinjau rencana sebelum digunakan.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warning,
                                      height: 1.5,
                                    ),
                                  ),
                                )
                            ],
                            Row(
                              children: [
                                if (plan != null) ...[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                            builder: (_) => FeedResultScreen(
                                                  plan: plan,
                                                  saved: true,
                                                )),
                                      ),
                                      child: Text(evaluation
                                          ? 'Lihat evaluasi'
                                          : 'Lihat rencana'),
                                    ),
                                  ),
                                  const SizedBox(width: 8)
                                ],
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) =>
                                              IndividualFeedEntryScreen(
                                                cattleId: c.id,
                                                initialCategory: category,
                                                loadFeeds: widget.loadFeeds,
                                              )),
                                    ),
                                    child: Text(
                                      plan == null
                                          ? 'Hitung pakan'
                                          : 'Hitung ulang',
                                    ),
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (category == ProductionCategory.beef)
                TextButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const FeedStockScreen())),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Stok & kebutuhan Beef')),
              if (category == ProductionCategory.dairy &&
                  store.activeDairy.isNotEmpty)
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const DairyDashboardScreen())),
                    child: const Text('Dairy & pemerahan')),
              const SectionHeading('Persiapan pakan'),
              Panel(
                padding: 8,
                child: ListTile(
                  leading: const Icon(
                    CupertinoIcons.bag,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Rekap kebutuhan pakan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Rekap bahan untuk 1, 7, atau 30 hari',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const FeedShoppingScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Panel(
                padding: 4,
                child: ListTile(
                  leading: const Icon(Icons.grid_view_rounded),
                  title: const Text('Pakan kelompok (opsional)'),
                  subtitle: Text(store.activeGroups.isEmpty
                      ? 'Untuk ternak banyak: gunakan jumlah dan bobot rata-rata.'
                      : '${store.activeGroups.length} kelompok aktif · kelola rencana kelompok'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const GroupListScreen())),
                ),
              ),
              const SizedBox(height: 18),
              if (category == ProductionCategory.beef)
                const InfoBanner(
                  'Rencana ini untuk sapi potong yang tidak bunting dan tidak menyusui. Sesuaikan pemberian dengan kondisi aktual dan arahan tenaga kesehatan hewan.',
                ),
            ],
          );
        },
      );
}
