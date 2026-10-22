import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../data/farm_backup_codec.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool busy = false;
  Future<void> copy() async {
    setState(() => busy = true);
    try {
      await Clipboard.setData(
        ClipboardData(
          text: jsonEncode(FarmScope.read(context).exportData()),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cadangan disalin. Tempel ke file teks dan simpan sebagai JSON.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> restore() async {
    setState(() => busy = true);
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (text == null || text.trim().isEmpty) {
        throw const FormatException(
          'Clipboard kosong. Salin isi file cadangan JSON terlebih dahulu.',
        );
      }
      final data = FarmBackupCodec.decode(text);
      if (!mounted) {
        return;
      }
      final yes = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Pulihkan cadangan ini?'),
          content: Text(
            '${data.farm}\n${data.cattle.length} sapi · ${data.feedPlans.length} rencana pakan\n\nSeluruh data di perangkat ini akan diganti dengan cadangan. Buat salinan data saat ini sebelum melanjutkan.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ganti & pulihkan'),
            )
          ],
        ),
      );
      if (yes == true) {
        await FarmScope.read(context).restoreBackup(text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data peternakan berhasil dipulihkan.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FarmPage(
        title: 'Cadangan yang\nbisa diandalkan.',
        subtitle:
            'Profil, foto, riwayat bobot, dan rencana pakan dalam satu salinan.',
        eyebrow: 'KELOLA DATA LOKAL',
        back: true,
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  CupertinoIcons.tray_arrow_up,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Buat salinan data',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Salin data, lalu tempel ke file teks dan simpan sebagai JSON di tempat yang aman.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : copy,
                  child: const Text('Salin cadangan JSON'),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  CupertinoIcons.tray_arrow_down,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pulihkan dari cadangan',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Salin isi cadangan JSON ke clipboard. Kami akan memeriksa datanya dan menampilkan ringkasan sebelum mengganti data saat ini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: busy ? null : restore,
                  child: const Text('Tempel & periksa cadangan'),
                )
              ],
            ),
          ),
          const SizedBox(height: 18),
          const InfoBanner(
            'Cadangan berisi data peternakan dan foto. Simpan secara pribadi. Cadangan tidak otomatis dikirim ke cloud.',
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CupertinoActivityIndicator()),
            ),
        ],
      );
}
