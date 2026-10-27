import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../domain/cattle.dart';
import '../../domain/milk_metrics.dart';
import '../../domain/records.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';

class DairyEventPage extends ConsumerStatefulWidget {
  const DairyEventPage({super.key, required this.cattle, required this.kind});
  final Cattle cattle;
  final DairyEventKind kind;
  @override
  ConsumerState<DairyEventPage> createState() => _DairyEventPageState();
}

class _DairyEventPageState extends ConsumerState<DairyEventPage> {
  final form = GlobalKey<FormState>();
  final note = TextEditingController(), parity = TextEditingController();
  late String date;
  String? until, relatedId;
  Pregnancy? pregnancy;
  bool dirty = false;
  @override
  void initState() {
    super.initState();
    date = day(ref.read(clockProvider)().toLocal());
  }

  @override
  void dispose() {
    note.dispose();
    parity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind,
        metrics = MilkMetrics(widget.cattle, ref.read(clockProvider)());
    final previousKnown = metrics.calving != null && metrics.parity != null;
    final services = widget.cattle.events
        .where((e) =>
            e.kind == DairyEventKind.service && e.date.compareTo(date) <= 0)
        .toList();
    return DraftGuard(
        dirty: dirty,
        child: PageFrame(
            title: kind.label,
            subtitle: widget.cattle.name,
            children: [
              Form(
                  key: form,
                  onChanged: () {
                    if (!dirty) setState(() => dirty = true);
                  },
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                            onPressed: () async {
                              final d = await chooseDay(context, date);
                              if (d != null) {
                                setState(() {
                                  date = d;
                                  dirty = true;
                                  relatedId = null;
                                });
                              }
                            },
                            icon: const Icon(Icons.event),
                            label: Text('Tanggal kejadian: ${dayText(date)}')),
                        const SizedBox(height: 14),
                        if (kind == DairyEventKind.pregnancyCheck)
                          DropdownButtonFormField<Pregnancy>(
                              value: pregnancy,
                              decoration: const InputDecoration(
                                  labelText: 'Hasil pemeriksaan manual'),
                              items: Pregnancy.values
                                  .map((v) => DropdownMenuItem(
                                      value: v, child: Text(v.label)))
                                  .toList(),
                              onChanged: (v) {
                                pregnancy = v;
                                dirty = true;
                              },
                              validator: (v) => v == null
                                  ? 'Pilih hasil pemeriksaan.'
                                  : null),
                        if (kind == DairyEventKind.confirmedConception)
                          DropdownButtonFormField<String>(
                              value: relatedId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Catatan IB yang dikonfirmasi'),
                              items: services
                                  .map((e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(
                                          '${dayText(e.date)} · ${e.note.isEmpty ? 'Breeding / IB' : e.note}',
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (v) {
                                relatedId = v;
                                dirty = true;
                              },
                              validator: (v) => v == null
                                  ? 'Pilih catatan IB yang mendasari konfirmasi.'
                                  : null),
                        if (kind == DairyEventKind.calving) ...[
                          const Notice(
                              'Catat hanya kelahiran yang benar-benar terjadi. DIM dihitung dari tanggal ini, tanpa menebak tanggal sebelumnya.'),
                          if (previousKnown)
                            Notice(
                                'Nomor laktasi berikutnya: ${metrics.parity! + 1}, dari nomor sebelumnya yang tercatat.')
                          else
                            TextFormField(
                                controller: parity,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText:
                                        'Nomor laktasi setelah kelahiran (bila diketahui)',
                                    helperText:
                                        'Kosongkan jika belum pasti. Tidak otomatis dianggap laktasi pertama.'),
                                onChanged: (_) => dirty = true,
                                validator: (v) => v == null || v.isEmpty
                                    ? null
                                    : int.tryParse(v) == null ||
                                            int.parse(v) <= 0
                                        ? 'Masukkan nomor laktasi positif.'
                                        : null),
                        ],
                        if (kind == DairyEventKind.withholding) ...[
                          const Notice(
                              'Tanggal akhir harus berasal dari pengguna, dokter hewan, atau label produk. Aplikasi tidak menentukan durasinya.'),
                          OutlinedButton.icon(
                              onPressed: () async {
                                final d = await chooseDay(
                                    context, until ?? date,
                                    allowFuture: true);
                                if (d != null) {
                                  setState(() {
                                    until = d;
                                    dirty = true;
                                  });
                                }
                              },
                              icon: const Icon(Icons.event_busy),
                              label: Text(until == null
                                  ? 'Pilih akhir masa tahan (termasuk tanggal itu)'
                                  : 'Ditahan sampai ${dayText(until!)} (termasuk)')),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: note,
                            maxLength: 1000,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Catatan / sumber (opsional)'),
                            onChanged: (_) => dirty = true),
                      ])),
              SubmitButton(
                  label: 'Simpan catatan',
                  submit: () async {
                    if (!form.currentState!.validate()) return;
                    await ref.read(farmProvider.notifier).dairyEvent(
                        widget.cattle.id,
                        kind: kind,
                        date: date,
                        note: note.text,
                        pregnancy: pregnancy,
                        parity: int.tryParse(parity.text),
                        until: until,
                        relatedId: relatedId,
                        expectedEventCount: widget.cattle.events.length);
                    if (context.mounted) {
                      dirty = false;
                      Navigator.pop(context);
                    }
                  }),
            ]));
  }
}
