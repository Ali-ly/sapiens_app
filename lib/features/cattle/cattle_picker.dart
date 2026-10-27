import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../domain/cattle.dart';
import '../../ui/components.dart';
import 'add_cattle_page.dart';
import 'cattle_card.dart';

Future<Cattle?> pickCattle(BuildContext context) =>
    openPage<Cattle>(context, const CattlePickerPage());

class CattlePickerPage extends ConsumerStatefulWidget {
  const CattlePickerPage({super.key});
  @override
  ConsumerState<CattlePickerPage> createState() => _CattlePickerPageState();
}

class _CattlePickerPageState extends ConsumerState<CattlePickerPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(farmProvider).requireValue;
    final rows = data.active.where((c) =>
        c.name.toLowerCase().contains(query.toLowerCase()) ||
        c.userId.toLowerCase().contains(query.toLowerCase()));
    return PageFrame(
        title: 'Pilih Sapi',
        subtitle: 'Proses berikutnya memakai konteks sapi yang kamu pilih.',
        children: [
          TextField(
              decoration: const InputDecoration(
                  labelText: 'Cari sapi', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => query = v)),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            EmptyMessage(
                title: 'Sapi tidak ditemukan',
                message: 'Tambahkan sapi dengan bobot awal terlebih dahulu.',
                action: OutlinedButton(
                    onPressed: () => openPage(context, const AddCattlePage()),
                    child: const Text('Tambah Sapi'))),
          for (final c in rows)
            CattleCard(
                cattle: c,
                mode: data.account!.mode,
                now: ref.watch(clockProvider)(),
                onTap: () => Navigator.pop(context, c)),
        ]);
  }
}
