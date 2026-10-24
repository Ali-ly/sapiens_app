import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../home/insights_screen.dart';
import 'backup_screen.dart';
import 'farm_settings_screen.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});
  void guide(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (_) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bobot → pakan → pantau.',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 22),
                ...[
                  'Tambahkan profil sapi dan umur dalam bulan.',
                  'Catat bobot dengan foto AI atau hasil timbangan.',
                  'Di tab Pakan, pilih target dan bahan yang tersedia.',
                  'Simpan rencana, lalu lihat takaran harian dan rekap kandang.',
                  'Saat bobot berubah, hitung ulang pakan agar sesuai.'
                ].asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primarySoft,
                              child: Text(
                                '${e.key + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                const InfoBanner(
                  'Rekomendasi awal untuk sapi potong yang tidak bunting dan tidak menyusui. Kondisi tubuh dicatat sebagai konteks dan belum mengubah takaran otomatis.',
                )
              ],
            ),
          ),
        ),
      );
  Future<void> removeExamples(BuildContext context) async {
    final store = FarmScope.read(context);
    final count = store.cattle.where((c) => c.id.startsWith('demo-')).length;
    final yes = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus data contoh?'),
        content: Text(
          '$count sapi yang berasal dari data contoh, termasuk perubahan dan rencana pakannya, akan dihapus. Sapi yang kamu tambahkan sendiri tetap tersimpan.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus contoh'),
          )
        ],
      ),
    );
    if (yes == true) {
      try {
        await store.removeExamples();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Data contoh dihapus. Sapi milikmu tetap tersimpan.'),
            ),
          );
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
          final initials = store.farmer
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((n) => n.isEmpty ? '' : n.substring(0, 1))
              .join()
              .toUpperCase();
          return FarmPage(
            title: 'Ruang peternakanmu.',
            subtitle: 'Kelola identitas, data, dan kebiasaan pencatatan.',
            eyebrow: 'PROFIL & PREFERENSI',
            children: [
              Panel(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: AppColors.primaryDark,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      store.farmer,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      store.farm,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const StatusPill('PETERNAKAN LOKAL · DATA DI PERANGKAT')
                  ],
                ),
              ),
              const SectionHeading('Peternakan'),
              Panel(
                padding: 6,
                child: Column(
                  children: [
                    _item(
                      CupertinoIcons.person_crop_circle,
                      'Identitas & preferensi',
                      'Nama peternakan dan interval pengecekan',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const FarmSettingsScreen()),
                      ),
                    ),
                    const Divider(indent: 56, endIndent: 15, height: 1),
                    _item(
                      CupertinoIcons.chart_bar,
                      'Ringkasan kandang',
                      'Bobot dan aktivitas pencatatan',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const InsightsScreen()),
                      ),
                    )
                  ],
                ),
              ),
              const SectionHeading('Data & bantuan'),
              Panel(
                padding: 6,
                child: Column(
                  children: [
                    _item(
                      CupertinoIcons.tray_arrow_down,
                      'Cadangan data',
                      'Salin dan pulihkan data peternakan',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const BackupScreen()),
                      ),
                    ),
                    const Divider(indent: 56, endIndent: 15, height: 1),
                    _item(
                      CupertinoIcons.book,
                      'Cara menggunakan SAPIENS',
                      'Alur bobot, kebutuhan pakan, dan pemantauan',
                      () => guide(context),
                    ),
                    if (store.cattle.any((c) => c.id.startsWith('demo-'))) ...[
                      const Divider(indent: 56, endIndent: 15, height: 1),
                      _item(
                        CupertinoIcons.trash,
                        'Hapus data contoh',
                        'Bersihkan contoh, pertahankan sapi milikmu',
                        () => removeExamples(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const InfoBanner(
                'Data disimpan pada perangkat ini, tanpa akun dan sinkronisasi cloud. Buat cadangan berkala sebelum menghapus aplikasi atau data browser.',
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'SAPIENS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              const Center(
                child: Text(
                  'Rawat sapimu. Rencanakan pakannya.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          );
        },
      );
  Widget _item(
          IconData icon, String title, String subtitle, VoidCallback tap) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        leading: Icon(icon, size: 23, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          size: 13,
          color: AppColors.textSecondary,
        ),
        onTap: tap,
      );
}
