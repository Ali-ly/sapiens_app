import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../models/beef/beef_feed_context.dart';
import '../../models/cattle.dart';
import '../../models/feed_plan.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import 'nutrition_result_screen.dart';

class FeedResultScreen extends StatefulWidget {
  const FeedResultScreen({super.key, required this.plan, this.saved = false});
  final FeedPlan plan;
  final bool saved;
  @override
  State<FeedResultScreen> createState() => _FeedResultScreenState();
}

class _FeedResultScreenState extends State<FeedResultScreen> {
  int days = 1;
  // The individual creation flow only produces v2 evaluations. Legacy
  // rations remain available as read-only history, including copy/day scaling.
  Future<void> copy() async {
    final p = widget.plan;
    final store = FarmScope.read(context);
    final c = store.byId(p.cattleId);
    final review = c == null ||
        !p.matches(c) ||
        BeefFeedContext.limitation(c, p.target!) != null ||
        c.productionCategory == ProductionCategory.beef &&
            p.beefContext?.matches(c) != true ||
        store.needsCheck(c) ||
        store.latestPlan(c.id)?.id != p.id;
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${review ? 'PERLU DITINJAU — perbarui rencana sebelum dipakai.\n' : ''}Rencana pakan — ${p.cattleName}\nBobot: ${kgLabel(p.weightKg)} kg\nTarget: ${targetLabels[p.target] ?? p.target}\nPeriode: $days hari\n${p.portions.map((f) => '${f.label}: ${kgLabel(f.asFedKg * days)} kg').join('\n')}\nDihitung ${dateLabel(p.createdAt)}\nTakaran adalah perkiraan dari layanan pakan, sesuaikan dengan kondisi sapi.',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rencana pakan disalin.')),
        );
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.plan.nutritionSnapshot != null
      ? NutritionResultScreen(plan: widget.plan, saved: widget.saved)
      : AnimatedBuilder(
          animation: FarmScope.read(context),
          builder: (context, _) {
            final p = widget.plan;
            final c = FarmScope.read(context).byId(p.cattleId);
            final unsupported = c != null &&
                (BeefFeedContext.limitation(c, p.target!) != null ||
                    c.productionCategory == ProductionCategory.beef &&
                        p.beefContext?.matches(c) != true);
            final stale = c == null || !p.matches(c) || unsupported;
            final overdue = c != null && FarmScope.read(context).needsCheck(c);
            final archived = c != null &&
                FarmScope.read(context).latestPlan(c.id)?.id != p.id;
            return FarmPage(
              title: 'Rencana pakan',
              subtitle: p.cattleName,
              eyebrow: 'NUTRISI · RENCANA TERSIMPAN',
              back: true,
              action: IconButton(
                tooltip: 'Salin rencana pakan',
                onPressed: copy,
                icon: const Icon(CupertinoIcons.square_on_square),
              ),
              children: [
                if (unsupported)
                  InfoBanner(
                      BeefFeedContext.limitation(c, p.target!) ??
                          'Rencana lama belum memiliki konteks Beef terkini; hitung ulang dalam mode terbatas.',
                      warning: true),
                if (archived)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: InfoBanner(
                      'Ini adalah riwayat rencana. Rencana pakan terbaru tersedia pada profil sapi.',
                      warning: true,
                    ),
                  ),
                if (stale || overdue)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: InfoBanner(
                      'Data sapi berubah atau bobot perlu diperbarui. Tinjau dan hitung ulang rencana ini sebelum dipakai.',
                      warning: true,
                    ),
                  ),
                Panel(
                  color: AppColors.primaryDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusPill(
                            targetLabels[p.target] ?? p.target!,
                            dark: true,
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.grass_rounded,
                            color: AppColors.accent,
                            size: 28,
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'TOTAL PAKAN SEGAR',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: Color(0xFFBBC9B7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${kgLabel(p.totalFreshKg)} kg',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -2,
                        ),
                      ),
                      const Text(
                        'per ekor / hari',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFBBC9B7),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Divider(color: Color(0xFF465444), height: 1),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Bobot ${kgLabel(p.weightKg)} kg',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          if (p.totalDryMatterKg != null)
                            Text(
                              'Bahan kering ${kgLabel(p.totalDryMatterKg!)} kg/hari',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            )
                        ],
                      )
                    ],
                  ),
                ),
                const SectionHeading('Rincian bahan pakan'),
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: days,
                  backgroundColor: AppColors.divider,
                  thumbColor: Colors.white,
                  children: const {
                    1: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Text('Harian', style: TextStyle(fontSize: 12)),
                    ),
                    7: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Text('7 hari', style: TextStyle(fontSize: 12)),
                    ),
                    30: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Text('30 hari', style: TextStyle(fontSize: 12)),
                    )
                  },
                  onValueChanged: (v) {
                    if (v != null) {
                      setState(() => days = v);
                    }
                  },
                ),
                const SizedBox(height: 14),
                ...p.portions.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  f.key == 'rumput'
                                      ? Icons.grass_rounded
                                      : f.key == 'jerami'
                                          ? Icons.spa_outlined
                                          : CupertinoIcons.cube_box,
                                  color: AppColors.primary,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      days == 1
                                          ? 'Pakan segar per hari'
                                          : 'Persiapan untuk $days hari',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${kgLabel(f.asFedKg * days)} kg',
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.7,
                                ),
                              )
                            ],
                          ),
                          if (f.ratio != null) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (f.ratio! / 100).clamp(0, 1).toDouble(),
                                minHeight: 5,
                                backgroundColor: AppColors.surfaceSoft,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${f.ratio!.toStringAsFixed(0)}% dari total bahan kering',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
                if (days != 1)
                  InfoBanner(
                    'Rekap $days hari adalah takaran harian × $days, dengan bobot dan kebutuhan diasumsikan tetap. Hitung ulang saat bobot atau kondisi berubah.',
                  ),
                const SectionHeading('Catatan pemberian'),
                if (p.warning != null && p.warning!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InfoBanner(p.warning!, warning: true),
                  ),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...p.notes.map(
                        (n) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  CupertinoIcons.check_mark,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  n,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      const Text(
                        'Pakan segar adalah jumlah bahan yang diberikan. Bahan kering tidak termasuk kadar air bahan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      )
                    ],
                  ),
                ),
                if (p.beefContext != null)
                  const InfoBanner(
                      'Rencana Beef mode terbatas: API memakai bobot, target umum, dan bahan. Purpose/fase bukan faktor nutrisi backend.'),
                const SectionHeading('Dasar rencana'),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Bobot saat dihitung', '${kgLabel(p.weightKg)} kg'),
                      _row('Target', targetLabels[p.target] ?? p.target!),
                      _row(
                        'Umur & kondisi dalam input',
                        '${p.ageMonths} bulan · ${p.bodyCondition}',
                      ),
                      _row('Tanggal hitung', dateLabel(p.createdAt)),
                      const SizedBox(height: 6),
                      const Text(
                        'Umur adalah snapshot input rencana, bukan umur terkini yang diverifikasi. Kepastian dan waktu acuan umur tidak disimpan pada rencana. Umur dan kondisi tubuh belum menjadi faktor hitung otomatis.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const InfoBanner(
                  'Perkiraan ini untuk sapi potong yang tidak bunting dan tidak menyusui. Kualitas bahan dan kondisi sapi memengaruhi kebutuhan aktual.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(CupertinoIcons.check_mark_circled, size: 20),
                  label: const Text('Selesai'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: copy,
                  icon: const Icon(CupertinoIcons.doc_on_doc, size: 17),
                  label: const Text('Salin rincian pakan'),
                ),
              ],
            );
          },
        );
  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            )
          ],
        ),
      );
}
