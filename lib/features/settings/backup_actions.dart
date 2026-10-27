import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';
import '../../data/backup_codec.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import '../cattle/cattle_page.dart';

abstract final class BackupActions {
  static Future<void> export(BuildContext context, WidgetRef ref) async {
    final raw = ref.read(farmProvider.notifier).export();
    final filename = 'sapiens-${day(ref.read(clockProvider)().toLocal())}.json';
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles([
      XFile.fromData(Uint8List.fromList(utf8.encode(raw)),
          mimeType: 'application/json', name: filename)
    ],
        fileNameOverrides: [
          filename
        ],
        subject: 'Cadangan SAPIENS',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size);
  }

  static Future<void> copy(WidgetRef ref) async => Clipboard.setData(
      ClipboardData(text: ref.read(farmProvider.notifier).export()));
  static Future<void> import(BuildContext context, WidgetRef ref) async {
    final expected = ref.read(farmProvider).valueOrNull;
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
        allowMultiple: false);
    if (picked == null) return;
    final bytes = picked.files.single.bytes;
    require(bytes != null, 'File cadangan tidak dapat dibaca.');
    final raw = utf8.decode(bytes!);
    final data = BackupCodec.decode(raw);
    if (!context.mounted) return;
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Pulihkan cadangan?'),
                content: Text(
                    '${data.account?.mode.label ?? 'Akun belum diatur'} · ${data.cattle.length} sapi\n\nSemua data lokal saat ini akan diganti. Simpan cadangan saat ini sebelum melanjutkan.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Ganti & pulihkan'))
                ]));
    if (yes != true) return;
    await ref.read(farmProvider.notifier).restore(raw, expected: expected);
    ref.invalidate(cattleQueryProvider);
    if (context.mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
      toast(context, 'Cadangan berhasil dipulihkan.');
    }
  }
}
