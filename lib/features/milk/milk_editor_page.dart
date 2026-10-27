import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/cattle.dart';
import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';

class MilkEditorPage extends ConsumerStatefulWidget {
  const MilkEditorPage({super.key, required this.cattle, this.record});
  final Cattle cattle;
  final MilkRecord? record;
  @override
  ConsumerState<MilkEditorPage> createState() => _MilkEditorPageState();
}

class _MilkEditorPageState extends ConsumerState<MilkEditorPage> {
  final form = GlobalKey<FormState>();
  final total = TextEditingController(),
      am = TextEditingController(),
      pm = TextEditingController();
  late String date;
  MilkMode mode = MilkMode.totalDaily;
  MilkUnit unit = MilkUnit.kg;
  MilkRecord? previous;
  bool dirty = false;
  @override
  void initState() {
    super.initState();
    date = widget.record?.date ?? day(ref.read(clockProvider)().toLocal());
    load(widget.record ??
        widget.cattle.milk.where((m) => m.date == date).lastOrNull);
  }

  void load(MilkRecord? record) {
    previous = record;
    mode = record?.mode ?? MilkMode.totalDaily;
    unit = record?.unit ?? MilkUnit.kg;
    total.text = record?.total?.toString() ?? '';
    am.text = record?.am?.toString() ?? '';
    pm.text = record?.pm?.toString() ?? '';
  }

  @override
  void dispose() {
    total.dispose();
    am.dispose();
    pm.dispose();
    super.dispose();
  }

  Widget input(String key, String label, TextEditingController controller) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              key: ValueKey(key),
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '$label (${unit.label})'),
              onChanged: (_) => dirty = true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = numeric(v);
                return n == null || !n.isFinite || n < 0
                    ? 'Masukkan jumlah nol atau lebih.'
                    : null;
              }));
  @override
  Widget build(BuildContext context) => DraftGuard(
      dirty: dirty,
      child: PageFrame(
          title: previous == null
              ? 'Catat produksi susu'
              : 'Koreksi produksi susu',
          subtitle: widget.cattle.name,
          children: [
            OutlinedButton.icon(
                onPressed: () async {
                  final d = await chooseDay(context, date);
                  if (d == null || !mounted) return;
                  final c = ref
                      .read(farmProvider)
                      .requireValue
                      .find(widget.cattle.id)!;
                  setState(() {
                    date = d;
                    load(c.milk.where((m) => m.date == d).lastOrNull);
                    dirty = true;
                  });
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('Tanggal: ${dayText(date)}')),
            if (previous != null)
              const Notice(
                  'Catatan hari ini sudah ada. Penyimpanan menjadi koreksi baru; catatan sebelumnya tetap tersimpan.'),
            const Heading('Cara pencatatan'),
            SegmentedButton<MilkMode>(
                segments: const [
                  ButtonSegment(
                      value: MilkMode.totalDaily, label: Text('Total harian')),
                  ButtonSegment(
                      value: MilkMode.amPm, label: Text('Pagi / Sore'))
                ],
                selected: {
                  mode
                },
                onSelectionChanged: (v) => setState(() {
                      mode = v.first;
                      dirty = true;
                    })),
            const SizedBox(height: 16),
            DropdownButtonFormField<MilkUnit>(
                isExpanded: true,
                itemHeight: null,
                value: unit,
                decoration:
                    const InputDecoration(labelText: 'Satuan pengukuran'),
                items: const [
                  DropdownMenuItem(
                      value: MilkUnit.kg,
                      child: Text('Kilogram — hasil penimbangan')),
                  DropdownMenuItem(
                      value: MilkUnit.liter,
                      child: Text('Liter — hasil pengukuran volume'))
                ],
                onChanged: (v) => setState(() {
                      unit = v!;
                      dirty = true;
                    })),
            const SizedBox(height: 14),
            if (unit == MilkUnit.liter)
              const Notice(
                  'Liter tetap disimpan sebagai liter. Backend nutrisi memerlukan kg; aplikasi tidak mengubah satuan tanpa dasar konversi.'),
            Form(
                key: form,
                onChanged: () {
                  if (!dirty) setState(() => dirty = true);
                },
                child: Column(
                    children: mode == MilkMode.totalDaily
                        ? [input('milk-total', 'Total susu per hari', total)]
                        : [
                            input('milk-am', 'Pemerahan pagi', am),
                            input('milk-pm', 'Pemerahan sore', pm)
                          ])),
            if (mode == MilkMode.amPm)
              const Notice(
                  'Boleh menyimpan satu sesi dulu. Sesi kosong berarti belum dicatat, bukan nol. Lengkapi melalui koreksi catatan hari yang sama.'),
            SubmitButton(
                label: previous == null
                    ? 'Simpan produksi susu'
                    : 'Simpan koreksi',
                submit: () async {
                  if (!form.currentState!.validate()) return;
                  await ref.read(farmProvider.notifier).milk(widget.cattle.id,
                      date: date,
                      mode: mode,
                      unit: unit,
                      total: mode == MilkMode.totalDaily
                          ? numeric(total.text)
                          : null,
                      am: mode == MilkMode.amPm ? numeric(am.text) : null,
                      pm: mode == MilkMode.amPm ? numeric(pm.text) : null,
                      expectedCurrentId: previous?.id);
                  if (context.mounted) {
                    dirty = false;
                    Navigator.pop(context);
                  }
                }),
          ]));
}
