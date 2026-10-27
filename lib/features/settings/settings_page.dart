import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import '../cattle/cattle_page.dart';
import 'backup_actions.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  Future<void> switchMode(BuildContext context, WidgetRef ref) async {
    final expected = ref.read(farmProvider).requireValue, a = expected.account!;
    final next = a.mode == FarmMode.beef ? FarmMode.dairy : FarmMode.beef;
    String confirmation = '';
    final yes = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                    title: Text('Ganti ke ${next.label}?'),
                    content: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Text(
                              '${expected.cattle.length} sapi beserta bobot, galeri, kondisi, reproduksi, susu, dan seluruh evaluasinya akan dihapus permanen. Mode baru dimulai kosong tanpa migrasi.'),
                          const SizedBox(height: 14),
                          const Text(
                              'Sebaiknya simpan Backup/Export terlebih dahulu. File cadangan di luar aplikasi tidak dihapus.'),
                          const SizedBox(height: 14),
                          TextField(
                              key: const ValueKey('confirm-mode-text'),
                              decoration: const InputDecoration(
                                  labelText: 'Ketik GANTI untuk mengonfirmasi'),
                              onChanged: (v) =>
                                  setDialog(() => confirmation = v))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal')),
                      FilledButton(
                          key: const ValueKey('confirm-mode-delete'),
                          onPressed: confirmation == 'GANTI'
                              ? () => Navigator.pop(ctx, true)
                              : null,
                          child: const Text('Hapus & ganti mode'))
                    ])));
    if (yes != true) return;
    await ref
        .read(farmProvider.notifier)
        .changeMode(next, expected: expected, confirmed: true);
    ref.invalidate(cattleQueryProvider);
    if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(farmProvider).requireValue,
        a = data.account!,
        health = ref.watch(gatewayHealthProvider);
    return PageFrame(
        title: 'Profil',
        back: false,
        subtitle: 'Akun & peternakan pada perangkat ini',
        children: [
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Icon(Icons.agriculture_outlined, size: 42),
                const SizedBox(height: 14),
                Text(a.farmName,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700)),
                Text(a.owner),
                const SizedBox(height: 14),
                Align(
                    alignment: Alignment.centerLeft, child: Tag(a.mode.farmer)),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: () => openPage(context, const AccountEditPage()),
                    child: const Text('Edit identitas peternakan'))
              ])),
          const Heading('Backup & data'),
          const Notice(
              'Data disimpan pada perangkat ini, tanpa akun cloud. Backup juga mencakup foto dan seluruh histori. Cadangan aplikasi lama tidak diimpor otomatis.'),
          SubmitButton(
              label: 'Backup / Export',
              submit: () => BackupActions.export(context, ref),
              icon: Icons.download_outlined),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: () async {
                try {
                  await BackupActions.copy(ref);
                  if (context.mounted) {
                    toast(context,
                        'JSON disalin. Simpan ke file di luar aplikasi.');
                  }
                } catch (e) {
                  if (context.mounted) toast(context, errorText(e));
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Salin JSON cadangan')),
          const SizedBox(height: 10),
          SubmitButton(
              label: 'Pulihkan dari file JSON',
              icon: Icons.restore,
              submit: () => BackupActions.import(context, ref)),
          const Heading('Koneksi layanan'),
          Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                health.when(
                    data: (j) => Text(j['status'] == 'healthy'
                        ? 'Gateway terhubung'
                        : 'Layanan mengirim status: ${j['status'] ?? 'belum diketahui'}'),
                    loading: () => const Text('Memeriksa layanan…'),
                    error: (e, _) => Text(errorText(e))),
                TextButton(
                    onPressed: () => ref.invalidate(gatewayHealthProvider),
                    child: const Text('Periksa lagi'))
              ])),
          const Heading('Jenis peternakan'),
          const Notice(
              'Ganti jenis peternakan adalah penghapusan permanen data akun ini. Tidak ada perpindahan data Potong ↔ Perah.',
              warning: true),
          SubmitButton(
              label: 'Ganti Jenis Peternakan',
              icon: Icons.swap_horiz,
              submit: () => switchMode(context, ref)),
          const SizedBox(height: 24),
          const Text(
              'SAPIENS · MVP baru\nBobot, kondisi, susu, dan pakan dalam satu profil sapi.',
              textAlign: TextAlign.center),
        ]);
  }
}

class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key});
  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController owner, name;
  bool dirty = false;
  @override
  void initState() {
    super.initState();
    final a = ref.read(farmProvider).requireValue.account!;
    owner = TextEditingController(text: a.owner);
    name = TextEditingController(text: a.farmName);
  }

  @override
  void dispose() {
    owner.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraftGuard(
      dirty: dirty,
      child: PageFrame(title: 'Identitas peternakan', children: [
        Form(
            key: form,
            onChanged: () {
              if (!dirty) setState(() => dirty = true);
            },
            child: Column(children: [
              TextFormField(
                  controller: owner,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Nama pemilik'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Isi nama pemilik.'
                      : null),
              const SizedBox(height: 16),
              TextFormField(
                  controller: name,
                  maxLength: 100,
                  decoration:
                      const InputDecoration(labelText: 'Nama peternakan'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Isi nama peternakan.'
                      : null)
            ])),
        const SizedBox(height: 24),
        SubmitButton(
            label: 'Simpan identitas',
            submit: () async {
              if (!form.currentState!.validate()) return;
              await ref
                  .read(farmProvider.notifier)
                  .account(owner.text, name.text);
              if (context.mounted) {
                dirty = false;
                Navigator.pop(context);
              }
            })
      ]));
}
