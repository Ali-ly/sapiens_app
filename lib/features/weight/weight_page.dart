import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/farm_controller.dart';
import '../../application/providers.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import 'weight_entry.dart';

class WeightPage extends ConsumerStatefulWidget {
  const WeightPage({super.key, required this.cattle});
  final Cattle cattle;
  @override
  ConsumerState<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends ConsumerState<WeightPage> {
  WeightInput? value;
  bool saved = false, dirty = false;
  @override
  Widget build(BuildContext context) => DraftGuard(
      dirty: dirty && !saved,
      child: PageFrame(
          title: 'Cek Berat Lagi',
          subtitle: widget.cattle.name,
          children: [
            const Notice(
                'Pengukuran baru menambah histori. Bobot lama dan fotonya tetap tersimpan.'),
            WeightEntry(
                onEdited: () {
                  if (!dirty) setState(() => dirty = true);
                },
                onChanged: (v) => setState(() => value = v)),
            const SizedBox(height: 24),
            SubmitButton(
                label: 'Simpan bobot',
                submit: () async {
                  require(value != null,
                      'Isi bobot manual atau selesaikan estimasi foto.');
                  await ref.read(farmProvider.notifier).addWeight(
                      widget.cattle.id, value!,
                      expectedWeight: widget.cattle.latestWeight.id);
                  if (context.mounted) {
                    saved = true;
                    Navigator.pop(context);
                    toast(context,
                        'Bobot tersimpan. Evaluasi pakan lama perlu ditinjau ulang.');
                  }
                }),
          ]));
}
