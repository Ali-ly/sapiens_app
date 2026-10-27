import 'package:flutter/material.dart';

import '../../models/production.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/form_save_error.dart';
import 'backup_screen.dart';

String farmTypeLabel(ProductionCategory? category) => switch (category) {
      ProductionCategory.beef => 'Sapi Pedaging',
      ProductionCategory.dairy => 'Sapi Perah',
      null => 'Jenis peternakan belum dipilih',
    };

class FarmProductionScreen extends StatefulWidget {
  const FarmProductionScreen({super.key, this.changing = false});
  final bool changing;
  @override
  State<FarmProductionScreen> createState() => _FarmProductionScreenState();
}

class _FarmProductionScreenState extends State<FarmProductionScreen> {
  bool busy = false;
  String? error;

  Future<void> select(ProductionCategory category) async {
    final store = FarmScope.read(context);
    final revision = store.productionChangeRevision;
    if (store.productionSystems?.singleCategory == category) {
      if (widget.changing) Navigator.pop(context);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final hasData = store.allCattle.isNotEmpty || store.feedPlans.isNotEmpty;
      if (widget.changing || hasData) {
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('Ganti ke ${farmTypeLabel(category)}?'),
            content: SingleChildScrollView(
                child: Text(
                    '${store.allCattle.length} sapi (termasuk arsip) dan seluruh histori bobot, foto, kesehatan, reproduksi, susu, serta rencana/evaluasi pakan individual akan dihapus permanen. Data tidak dapat dipulihkan tanpa cadangan yang sudah kamu simpan.\n\nIdentitas peternakan, kelompok, dan stok pakan tetap tersimpan.')),
            actions: [
              TextButton(
                  key: const ValueKey('farm-type-cancel'),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              FilledButton(
                  key: const ValueKey('farm-type-confirm-delete'),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Hapus permanen & ganti')),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      await store.selectFarmProduction(category,
          expectedRevision: revision, confirmPermanentDeletion: hasData);
      if (mounted && widget.changing) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FarmPage(
        title: widget.changing
            ? 'Ganti jenis peternakan'
            : 'Kamu beternak sapi apa?',
        subtitle:
            'Pilih sekali di awal. Pencatatan ternak dan pakan akan mengikuti jenis peternakanmu.',
        eyebrow: 'SAPIENS / JENIS PETERNAKAN',
        back: widget.changing,
        children: [
          if (widget.changing)
            InfoBanner(
                'Saat ini: ${farmTypeLabel(FarmScope.read(context).productionSystems?.singleCategory)}. Mengganti jenis akan menghapus semua sapi dan historinya secara permanen.',
                warning: true),
          for (final category in ProductionCategory.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: OutlinedButton(
                key: ValueKey('farm-type-${category.name}'),
                onPressed: busy ? null : () => select(category),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(children: [
                    Icon(
                        category == ProductionCategory.beef
                            ? Icons.grass
                            : Icons.water_drop_outlined,
                        size: 32),
                    const SizedBox(width: 18),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(farmTypeLabel(category),
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(
                              category == ProductionCategory.beef
                                  ? 'Pantau pertumbuhan, penggemukan, dan pembibitan.'
                                  : 'Catat susu, laktasi, dan reproduksi ternak perah.',
                              style: const TextStyle(height: 1.5)),
                        ])),
                    const Icon(Icons.arrow_forward),
                  ]),
                ),
              ),
            ),
          if (!widget.changing && FarmScope.read(context).allCattle.isNotEmpty)
            const InfoBanner(
                'Data lama ditemukan. Memilih jenis peternakan memerlukan konfirmasi penghapusan seluruh sapi dan historinya.',
                warning: true),
          if (busy) const Text('Menunggu konfirmasi atau menyimpan pilihan…'),
          TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const BackupScreen())),
              child: const Text('Cadangkan / pulihkan data')),
          if (error != null) FormSaveError(message: error!),
        ],
      );
}
