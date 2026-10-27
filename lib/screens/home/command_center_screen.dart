import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/farm_command_center.dart';
import '../../models/production.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../beef/beef_dashboard_screen.dart';
import '../cattle/add_cattle_screen.dart';
import '../cattle/cattle_profile_screen.dart';
import '../dairy/dairy_dashboard_screen.dart';
import '../feed/feed_result_screen.dart';
import '../feed/feed_shopping_screen.dart';
import '../profile/backup_screen.dart';
import '../profile/farm_production_screen.dart';
import '../profile/farm_settings_screen.dart';
import 'farm_actions_screen.dart';
import 'insights_screen.dart';
import 'widgets/farm_action_tile.dart';
import 'widgets/farm_feed_summary.dart';
import 'widgets/farm_metric_card.dart';

class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen(
      {super.key,
      required this.onCattle,
      required this.onFeed,
      required this.onGroups});
  final ValueChanged<String> onCattle;
  final VoidCallback onFeed, onGroups;

  void open(BuildContext context, Widget page) => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: FarmScope.read(context),
        builder: (context, _) {
          final store = FarmScope.read(context);
          final center = store.commandCenter;
          final empty = center.cattleCount == 0;
          return FarmPage(
            title: store.farmer == 'Peternak'
                ? 'Selamat datang di SAPIENS.'
                : 'Halo, ${store.farmer}.',
            subtitle:
                '${farmTypeLabel(store.productionSystems?.singleCategory)} · ${store.farm} · ${dateLabel(center.asOf)}',
            eyebrow: 'SAPIENS / FARM COMMAND CENTER',
            action: IconButton(
              tooltip: 'Pengaturan peternakan',
              icon: const Icon(CupertinoIcons.slider_horizontal_3),
              onPressed: () => open(context, const FarmSettingsScreen()),
            ),
            children: [
              if (store.error != null) ...[
                InfoBanner(store.error!, warning: true),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: store.load,
                      child: const Text('Coba baca ulang'),
                    ),
                    TextButton(
                      onPressed: () => open(context, const BackupScreen()),
                      child: const Text('Pulihkan cadangan'),
                    ),
                  ],
                ),
              ],
              if (store.demo)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: StatusPill(
                    'DATA CONTOH · BUKAN KONDISI KANDANG NYATA',
                  ),
                ),
              Panel(
                color: AppColors.primaryDark,
                padding: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatusPill('KENDALI OPERASIONAL', dark: true),
                    const SizedBox(height: 20),
                    Text(
                      store.error != null
                          ? 'Periksa data lokal'
                          : empty
                              ? 'Mulai dari sapi pertamamu.'
                              : '${center.cattleCount} sapi, setiap catatan berarti.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      empty
                          ? 'Tambah sapi, catat bobotnya, lalu hitung kebutuhan pakan. Pantau perkembangannya lewat riwayat.'
                          : 'Bobot lebih dulu, lalu rencana pakan. Prioritas disusun dari catatan kandangmu.',
                      style: const TextStyle(
                        color: Color(0xFFBBC9B7),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.primaryDark,
                      ),
                      onPressed: store.error != null
                          ? () => open(context, const BackupScreen())
                          : empty
                              ? () => open(context, const AddCattleScreen())
                              : () => onCattle('Semua'),
                      icon: Icon(
                        store.error != null
                            ? CupertinoIcons.tray_arrow_down
                            : empty
                                ? CupertinoIcons.add
                                : CupertinoIcons.arrow_right,
                        size: 18,
                      ),
                      label: Text(
                        store.error != null
                            ? 'Periksa cadangan'
                            : empty
                                ? 'Tambah sapi pertama'
                                : 'Lihat sapimu',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FarmMetricCard(
                        value: '${center.cattleCount}',
                        label: 'Profil individual',
                        icon: CupertinoIcons.square_stack_3d_up,
                        width: width,
                        onTap: () => onCattle('Semua'),
                      ),
                      FarmMetricCard(
                        value: '${center.weightAttentionCount}',
                        label: 'Perlu catatan bobot',
                        icon: CupertinoIcons.gauge,
                        width: width,
                        onTap: () => onCattle('Perlu dicek'),
                      ),
                      FarmMetricCard(
                        value: '${center.readyCount}/${center.cattleCount}',
                        label: 'Rencana pakan terkini',
                        icon: Icons.grass_rounded,
                        width: width,
                        onTap: onFeed,
                      ),
                      FarmMetricCard(
                        value: '${kgLabel(center.recordedWeightKg)} kg',
                        label: 'Total bobot tercatat',
                        icon: CupertinoIcons.chart_bar,
                        width: width,
                        onTap: () => open(context, const InsightsScreen()),
                      ),
                    ],
                  );
                },
              ),
              if (!empty) ...[
                SectionHeading(
                  'Prioritas kandang',
                  action: TextButton(
                    onPressed: () => open(context, const FarmActionsScreen()),
                    child: const Text('Lihat semua'),
                  ),
                ),
                if (center.actions.isEmpty)
                  const InfoBanner(
                    'Catatan bobot dan rencana pakan sudah terkini. Status ini bukan penilaian kesehatan sapi.',
                  ),
                ...center.actions
                    .take(3)
                    .map((action) => FarmActionTile(action: action)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => open(context, const AddCattleScreen()),
                  icon: const Icon(CupertinoIcons.add, size: 18),
                  label: const Text('Tambah sapi'),
                ),
              ],
              SectionHeading(
                'Kesiapan pakan',
                action: TextButton(
                  onPressed: onFeed,
                  child: const Text('Kelola'),
                ),
              ),
              FarmFeedSummary(
                center: center,
                onPrepareFeed: () => open(context, const FeedShoppingScreen()),
              ),
              if (store.activeBeef.isNotEmpty)
                TextButton.icon(
                    onPressed: () => open(context, const BeefDashboardScreen()),
                    icon: const Icon(Icons.insights_outlined),
                    label: Text(
                        'Ringkasan Beef · ${store.activeBeef.length} sapi aktif')),
              if (store.activeDairy.isNotEmpty) const DairyHomeSummary(),
              const SectionHeading('Aktivitas terbaru'),
              if (center.activity.isEmpty)
                const InfoBanner(
                  'Belum ada aktivitas. Catatan bobot dan rencana yang disimpan akan muncul di sini.',
                ),
              ...center.activity.take(5).map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Panel(
                        padding: 4,
                        child: ListTile(
                          leading: Icon(
                            event.kind == FarmActivityKind.weight
                                ? CupertinoIcons.gauge
                                : Icons.grass_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            event.cattle.nameOrId,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            event.kind == FarmActivityKind.weight
                                ? '${kgLabel(event.weightKg!)} kg · ${event.source == 'ai' ? 'Estimasi foto' : event.source == 'manual' ? 'Timbangan manual' : event.source == 'demo' ? 'Data contoh' : 'Catatan bobot'}\n${dateLabel(event.date)}'
                                : 'Rencana pakan disimpan · ${dateLabel(event.date)}',
                          ),
                          isThreeLine: event.kind == FarmActivityKind.weight,
                          trailing: const Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                          ),
                          onTap: () => open(
                            context,
                            event.kind == FarmActivityKind.weight
                                ? CattleProfileScreen(
                                    cattle: event.cattle,
                                    initialSection: CattleProfileSection.weight,
                                  )
                                : FeedResultScreen(
                                    plan: event.plan!,
                                    saved: true,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onGroups,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Kelompok/kandang (opsional)'),
              ),
              const Text(
                'Untuk mengelola banyak sapi sekaligus dengan data kelompok.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ringkasan berasal dari data lokal perangkat ini. Belum terhubung ke sensor atau pemantauan langsung.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          );
        },
      );
}
