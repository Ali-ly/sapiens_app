import 'package:flutter/material.dart';

import '../../models/feed_plan.dart';
import '../../models/feed_stock.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/form_save_error.dart';
import '../../widgets/livestock_labels.dart';
import '../../widgets/unsaved_changes_guard.dart';

class FeedStockScreen extends StatefulWidget {
  const FeedStockScreen({super.key});
  @override
  State<FeedStockScreen> createState() => _FeedStockScreenState();
}

class _FeedStockScreenState extends State<FeedStockScreen> {
  int days = 7;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final store = FarmScope.read(context), d = store.beefDemand(days);
        return FarmPage(
            title: 'Stok & kebutuhan Beef',
            subtitle: 'Stok farm · kebutuhan sapi Beef individual aktif',
            back: true,
            children: [
              const InfoBanner(
                  'Satuan kg pakan segar. Kebutuhan kelompok dan Dairy tidak digabung untuk menghindari hitung ganda. Pemakaian stok harus dicatat manual.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const StockEntryEditor())),
                  icon: const Icon(Icons.add),
                  label: const Text('Catat transaksi stok')),
              Wrap(spacing: 8, children: [
                for (final n in [1, 7, 30])
                  ChoiceChip(
                      label: Text('$n hari'),
                      selected: days == n,
                      onSelected: (_) => setState(() => days = n))
              ]),
              Text(
                  '${d.eligible} dari ${d.total} sapi Beef memiliki rencana yang memenuhi syarat.'),
              if (d.excluded.isNotEmpty)
                InfoBanner(
                    'Belum masuk rekap (tanpa rencana, lama/tertinggal, atau konteks tidak didukung): ${d.excluded.join(', ')}. Total ini hanya kebutuhan sebagian.',
                    warning: true),
              for (final f in d.ingredients)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Panel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(feedLabels[f]!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                              'Stok ${kgLabel(d.stock[f] ?? 0)} kg · harian ${kgLabel(d.daily[f] ?? 0)} kg'),
                          Text(
                              'Kebutuhan $days hari: ${kgLabel(d.requiredKg(f))} kg'),
                          if (d.shortageKg(f) > 0)
                            Text('Kekurangan ${kgLabel(d.shortageKg(f))} kg',
                                style:
                                    const TextStyle(color: Colors.deepOrange)),
                          Text(d.daysRemaining(f) == null
                              ? 'Kecukupan belum dapat dihitung tanpa kebutuhan aktif.'
                              : 'Estimasi cukup ${d.daysRemaining(f)!.toStringAsFixed(1)} hari pada kebutuhan saat ini.'),
                        ]))),
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                      'Proyeksi = kebutuhan harian × hari, tanpa perubahan bobot/kebutuhan atau susut stok. Stok tidak berkurang otomatis.')),
              if (store.feedStock
                  .any((e) => e.recordedAt.isAfter(store.currentTime)))
                const InfoBanner(
                    'Transaksi bertanggal masa depan tidak masuk saldo saat ini. Tinjau waktu perangkat/cadangan.',
                    warning: true),
              const SectionHeading('Histori transaksi'),
              if (store.feedStock.isEmpty)
                const Text('Belum ada transaksi stok.'),
              ...store.feedStock.reversed.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${feedLabels[e.feed]} · ${e.delta > 0 ? '+' : ''}${kgLabel(e.delta)} kg'),
                  subtitle: Text(
                      '${e.note}\n${timestampLabel(e.recordedAt, null)}'))),
            ]);
      });
}

class StockEntryEditor extends StatefulWidget {
  const StockEntryEditor({super.key});
  @override
  State<StockEntryEditor> createState() => _StockEntryEditorState();
}

class _StockEntryEditorState extends State<StockEntryEditor> {
  final form = GlobalKey<FormState>(),
      quantity = TextEditingController(),
      note = TextEditingController();
  String feed = 'rumput';
  StockMovement kind = StockMovement.received;
  String? error;
  bool dirty = false, busy = false;
  late final String farmId;
  late final int revision;
  @override
  void initState() {
    super.initState();
    final store = FarmScope.read(context);
    farmId = store.farmId;
    revision = store.feedStock.length;
  }

  @override
  void dispose() {
    quantity.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FarmScope.read(context).recordStock(
          feed: feed,
          kind: kind,
          kg: double.parse(quantity.text.replaceAll(',', '.')),
          note: note.text,
          expectedRevision: revision,
          expectedFarmId: farmId);
      if (!mounted) return;
      dirty = false;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
      dirty: dirty,
      busy: busy,
      child: FarmPage(
          title: 'Transaksi stok',
          subtitle: 'kg pakan segar · waktu pencatatan saat simpan',
          back: true,
          children: [
            Panel(
                child: AbsorbPointer(
                    absorbing: busy,
                    child: Form(
                        key: form,
                        onChanged: () => setState(() => dirty = true),
                        child: Column(children: [
                          DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: feed,
                              decoration:
                                  const InputDecoration(labelText: 'Bahan'),
                              items: feedLabels.entries
                                  .map((e) => DropdownMenuItem(
                                      value: e.key, child: Text(e.value)))
                                  .toList(),
                              onChanged: (v) => setState(() => feed = v!)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<StockMovement>(
                              isExpanded: true,
                              value: kind,
                              decoration: const InputDecoration(
                                  labelText: 'Jenis transaksi'),
                              items: const [
                                DropdownMenuItem(
                                    value: StockMovement.received,
                                    child: Text('Stok masuk')),
                                DropdownMenuItem(
                                    value: StockMovement.used,
                                    child: Text('Pemakaian')),
                                DropdownMenuItem(
                                    value: StockMovement.correction,
                                    child: Text('Koreksi (+/-)'))
                              ],
                              onChanged: (v) => setState(() => kind = v!)),
                          const SizedBox(height: 16),
                          TextFormField(
                              key: const ValueKey('stock-kg'),
                              controller: quantity,
                              decoration: const InputDecoration(
                                  labelText: 'Jumlah (kg pakan segar)'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              validator: (v) => double.tryParse(
                                          (v ?? '').replaceAll(',', '.')) ==
                                      null
                                  ? 'Isi angka.'
                                  : null),
                          const SizedBox(height: 16),
                          TextFormField(
                              key: const ValueKey('stock-note'),
                              controller: note,
                              decoration: const InputDecoration(
                                  labelText: 'Catatan / alasan'),
                              maxLength: 2000,
                              validator: (v) => v!.trim().isEmpty
                                  ? 'Catatan diperlukan.'
                                  : null),
                        ])))),
            const InfoBanner(
                'Koreksi menambah transaksi bertanda positif/negatif, bukan mengganti histori. Pemakaian tidak boleh melebihi stok tersedia.'),
            if (error != null) FormSaveError(message: error!),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Simpan transaksi stok')),
          ]));
}
