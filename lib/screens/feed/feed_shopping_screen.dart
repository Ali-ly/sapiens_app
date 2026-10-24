import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../models/feed_plan.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';

class FeedShoppingScreen extends StatefulWidget {
  const FeedShoppingScreen({super.key, this.initialGroupScope = false});
  final bool initialGroupScope;
  @override
  State<FeedShoppingScreen> createState() => _FeedShoppingScreenState();
}

class _FeedShoppingScreenState extends State<FeedShoppingScreen> {
  int days = 7;
  late bool groupScope = widget.initialGroupScope;
  final Set<String> checked = {};
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: FarmScope.read(context),
        builder: (context, _) {
          final store = FarmScope.read(context);
          final grouped = groupScope;
          final totals =
              grouped ? store.groupDailyFeedTotals : store.dailyFeedTotals;
          final count = grouped
              ? store.activeGroups.where(store.groupPlanReady).length
              : store.cattle.where(store.planReady).length;
          final totalCount =
              grouped ? store.activeGroups.length : store.cattle.length;
          final scopeLabel = grouped ? 'kelompok' : 'profil individual';
          final sum = totals.values.fold(0.0, (a, b) => a + b) * days;
          return FarmPage(
            title: 'Persiapan pakan',
            subtitle:
                'Rekap kelompok dan profil individual dipisahkan agar tidak dihitung dua kali.',
            eyebrow: 'REKAP KEBUTUHAN',
            back: true,
            children: [
              Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: const Text('Individual'),
                    selected: !grouped,
                    onSelected: (_) => setState(() {
                          groupScope = false;
                          checked.clear();
                        })),
                ChoiceChip(
                    label: const Text('Kelompok'),
                    selected: grouped,
                    onSelected: (_) => setState(() {
                          groupScope = true;
                          checked.clear();
                        }))
              ]),
              const SizedBox(height: 12),
              Panel(
                color: AppColors.primaryDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(
                      '$count $scopeLabel dengan rencana terkini',
                      dark: true,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${kgLabel(sum)} kg',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.5,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'total pakan segar untuk $days hari',
                      style: const TextStyle(
                        color: Color(0xFFBBC9B7),
                        fontSize: 13,
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: days,
                backgroundColor: AppColors.divider,
                children: const {
                  1: Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('1 hari', style: TextStyle(fontSize: 12)),
                  ),
                  7: Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('7 hari', style: TextStyle(fontSize: 12)),
                  ),
                  30: Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('30 hari', style: TextStyle(fontSize: 12)),
                  )
                },
                onValueChanged: (v) {
                  if (v != null) {
                    setState(
                      () {
                        days = v;
                        checked.clear();
                      },
                    );
                  }
                },
              ),
              if (count < totalCount)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: InfoBanner(
                    '${totalCount - count} $scopeLabel belum masuk rekap karena belum memiliki rencana terkini.',
                    warning: true,
                  ),
                ),
              const SectionHeading('Daftar bahan'),
              if (totals.isEmpty)
                const EmptyPanel(
                  title: 'Belum ada rencana siap pakai',
                  message:
                      'Hitung dan simpan rencana pakan pada cakupan yang dipilih terlebih dahulu. Rekap akan muncul di sini.',
                ),
              ...totals.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    padding: 7,
                    child: CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      value: checked.contains(e.key),
                      onChanged: (v) => setState(
                        () {
                          if (v == true) {
                            checked.add(e.key);
                          } else {
                            checked.remove(e.key);
                          }
                        },
                      ),
                      title: Text(
                        feedLabels[e.key] ?? e.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${kgLabel(e.value * days)} kg / $days hari',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const InfoBanner(
                'Takaran dijumlahkan dari rencana terkini pada cakupan terpilih, lalu dikalikan jumlah hari. Perbarui jika bobot atau kebutuhan berubah. Tanda centang hanya membantu persiapan selama halaman ini terbuka.',
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: totals.isEmpty
                    ? null
                    : () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(
                              text:
                                  'Kebutuhan pakan ${store.farm}\n$count $scopeLabel · $days hari\n${totals.entries.map((e) => '${feedLabels[e.key] ?? e.key}: ${kgLabel(e.value * days)} kg').join('\n')}\nTotal ${kgLabel(sum)} kg pakan segar',
                            ),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Daftar bahan disalin.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showError(context, e);
                          }
                        }
                      },
                icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                label: const Text('Salin daftar bahan'),
              ),
            ],
          );
        },
      );
}
