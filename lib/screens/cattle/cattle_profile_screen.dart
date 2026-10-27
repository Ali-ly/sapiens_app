import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/livestock_labels.dart';
import '../../widgets/photo_preview.dart';
import '../beef/beef_module_screen.dart';
import '../dairy/dairy_module_screen.dart';
import '../feed/feed_result_screen.dart';
import 'add_cattle_screen.dart';
import 'cattle_photo_screen.dart';
import 'widgets/cattle_feed_panel.dart';
import 'widgets/shared_twin_panel.dart';
import 'widgets/weight_chart.dart';
import 'widgets/weight_entry_dialog.dart';

enum CattleProfileSection { overview, weight, feed }

class CattleProfileScreen extends StatefulWidget {
  const CattleProfileScreen(
      {super.key,
      required this.cattle,
      this.initialSection = CattleProfileSection.overview});
  final Cattle cattle;
  final CattleProfileSection initialSection;
  @override
  State<CattleProfileScreen> createState() => _CattleProfileScreenState();
}

class _CattleProfileScreenState extends State<CattleProfileScreen> {
  late int section;
  @override
  void initState() {
    super.initState();
    section = widget.initialSection.index;
  }

  Future<void> manual(BuildContext context, Cattle c) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => WeightEntryDialog(cattle: c),
    );
    if (done == true && context.mounted) {
      setState(() => section = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bobot tersimpan. Hitung ulang pakan dengan bobot terbaru.',
          ),
        ),
      );
    }
  }

  Future<void> photo(BuildContext context, Cattle c) async {
    await Navigator.push<Cattle>(
      context,
      MaterialPageRoute(
        builder: (_) => CattlePhotoScreen(draft: c),
      ),
    );
    if (mounted) {
      setState(() => section = 2);
    }
  }

  Future<void> remove(BuildContext context, Cattle c) async {
    final store = FarmScope.read(context);
    final yes = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Arsipkan sapi ini?'),
        content: Text(
          '${c.nameOrId} akan dikeluarkan dari daftar aktif. Profil, foto, bobot, dan rencana pakan tetap tersimpan di Arsip.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arsipkan'),
          )
        ],
      ),
    );
    if (yes == true) {
      try {
        await store.remove(c.id);
        if (context.mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          showError(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: FarmScope.read(context),
        builder: (context, _) {
          final store = FarmScope.read(context);
          final c = store.byId(widget.cattle.id);
          if (c == null) {
            return const FarmPage(
                title: 'Profil tidak tersedia',
                subtitle: 'Kembali ke daftar ternak.',
                back: true,
                children: []);
          }
          final plan = store.latestPlan(c.id);
          final active = store.planReady(c);
          final history = store.feedPlans
              .where((p) => p.cattleId == c.id)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final delta = c.history.length < 2
              ? null
              : c.history.last.weightKg - c.history.first.weightKg;
          return FarmPage(
            title: c.nameOrId,
            subtitle: c.isActive
                ? (c.productionCategory == ProductionCategory.beef
                    ? 'Sapi Pedaging · pertumbuhan, pakan, dan pembibitan.'
                    : c.productionCategory == ProductionCategory.dairy
                        ? 'Sapi Perah · susu, laktasi, dan reproduksi.'
                        : 'Profil lama belum diklasifikasi.')
                : 'Status: ${c.status.label}. Seluruh catatan tetap tersimpan.',
            eyebrow: 'PROFIL TERNAK',
            back: true,
            action: IconButton(
              tooltip: 'Edit profil sapi',
              style: IconButton.styleFrom(backgroundColor: Colors.white),
              onPressed: !c.isActive
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => AddCattleScreen(cattle: c)),
                      ),
              icon: const Icon(CupertinoIcons.pencil, size: 20),
            ),
            children: [
              Panel(
                child: Row(
                  children: [
                    CattleAvatar(cattle: c, size: 76),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.gender} · ${ageEvidenceLabel(c)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              '${productionLabel(c.productionCategory)} · ${c.status.label}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 11),
                          StatusPill(
                            !c.isActive
                                ? c.status.label
                                : store.needsCheck(c)
                                    ? 'Waktunya cek bobot'
                                    : 'Bobot terkini',
                            warning: store.needsCheck(c),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Panel(
                color: AppColors.primaryDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BOBOT TERAKHIR',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: Color(0xFFBBC9B7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.estimatedWeight == null
                          ? 'Belum tercatat'
                          : '${kgLabel(c.estimatedWeight!)} kg',
                      style: TextStyle(
                        fontSize: c.estimatedWeight == null ? 28 : 48,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      c.history.isEmpty
                          ? 'Catat bobot pertama untuk menghitung pakan.'
                          : '${timestampLabel(c.history.last.date, c.history.last.dateText)} · ${c.history.last.sourceLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFBBC9B7),
                      ),
                    ),
                    if (delta != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: StatusPill(
                          '${delta >= 0 ? '+' : ''}${kgLabel(delta)} kg sejak catatan pertama',
                          dark: true,
                        ),
                      )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: c.isActive ? () => photo(context, c) : null,
                icon: const Icon(CupertinoIcons.camera, size: 20),
                label: const Text('Estimasi bobot dari foto'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: c.isActive ? () => manual(context, c) : null,
                icon: const Icon(CupertinoIcons.gauge, size: 20),
                label: const Text('Catat bobot manual'),
              ),
              const SizedBox(height: 24),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: section,
                backgroundColor: AppColors.divider,
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Ringkasan', style: TextStyle(fontSize: 12)),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Bobot', style: TextStyle(fontSize: 12)),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Pakan', style: TextStyle(fontSize: 12)),
                  )
                },
                onValueChanged: (v) {
                  if (v != null) {
                    setState(() => section = v);
                  }
                },
              ),
              if (section == 0) ...[
                if (c.productionCategory == ProductionCategory.beef)
                  BeefProfilePanel(cattle: c),
                if (c.productionCategory == ProductionCategory.dairy)
                  DairyProfilePanel(cattle: c),
                const SectionHeading('Perkembangan bobot'),
                if (c.history.length < 2)
                  const Panel(
                    child: Text(
                      'Grafik akan muncul setelah ada minimal dua catatan bobot.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  Panel(
                    child: Column(
                      children: [
                        Semantics(
                          label:
                              'Grafik ${c.history.length} catatan bobot, dari ${kgLabel(c.history.first.weightKg)} ke ${kgLabel(c.history.last.weightKg)} kilogram',
                          child: SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: CustomPaint(painter: WeightChart(c.history)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateLabel(c.history.first.date),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              dateLabel(c.history.last.date),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                const SectionHeading('Rencana pakan'),
                CattleFeedPanel(cattle: c, plan: plan, active: active),
                const SectionHeading('Catatan ternak'),
                Panel(
                  child: Text(
                    c.notes.isEmpty ? 'Belum ada catatan tambahan.' : c.notes,
                    style: const TextStyle(fontSize: 13, height: 1.7),
                  ),
                ),
                SharedTwinPanel(cattle: c),
                if (c.images.isNotEmpty) ...[
                  const SectionHeading('Galeri foto'),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: c.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: PhotoPreview(
                          image: c.images[i],
                          width: 170,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  )
                ],
              ] else if (section == 1) ...[
                SectionHeading(
                  'Riwayat bobot',
                  action: StatusPill('${c.history.length} catatan'),
                ),
                if (c.history.isEmpty)
                  const EmptyPanel(
                    title: 'Belum ada catatan',
                    message:
                        'Ambil foto untuk estimasi bobot atau catat hasil timbangan.',
                  )
                else
                  ...c.history.reversed.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        padding: 17,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                r.source == 'ai'
                                    ? CupertinoIcons.camera
                                    : CupertinoIcons.gauge,
                                color: AppColors.primary,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    timestampLabel(r.date, r.dateText),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    r.sourceLabel,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                ],
                              ),
                            ),
                            Text(
                              '${kgLabel(r.weightKg)} kg',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.5,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
              ] else ...[
                const SectionHeading('Pakan untuk sapi ini'),
                CattleFeedPanel(cattle: c, plan: plan, active: active),
                if (history.isNotEmpty) ...[
                  const SectionHeading('Riwayat rencana'),
                  ...history.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Panel(
                        padding: 6,
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => FeedResultScreen(
                                      plan: p,
                                      saved: true,
                                    )),
                          ),
                          leading: const Icon(
                            Icons.grass_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            '${kgLabel(p.totalFreshKg)} kg / hari',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${dateLabel(p.createdAt)} · bobot ${kgLabel(p.weightKg)} kg',
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: const Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                ]
              ],
              const SizedBox(height: 26),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: c.isActive
                    ? () => remove(context, c)
                    : c.status == CattleStatus.archived
                        ? () async {
                            try {
                              await store.setCattleStatus(
                                  c.id, CattleStatus.active,
                                  note: 'Pulihkan dari arsip',
                                  expectedEventCount: c.core.timeline.length);
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            }
                          }
                        : null,
                icon: Icon(
                    c.isActive
                        ? CupertinoIcons.archivebox
                        : CupertinoIcons.arrow_counterclockwise,
                    size: 17),
                label: Text(c.isActive
                    ? 'Arsipkan sapi'
                    : c.status == CattleStatus.archived
                        ? 'Pulihkan dari arsip'
                        : c.status.label),
              ),
            ],
          );
        },
      );
}
