import 'package:flutter/material.dart';

import '../../../models/cattle.dart';
import '../../../state/farm_scope.dart';
import '../../../widgets/farm_ui.dart';

class WeightEntryDialog extends StatefulWidget {
  const WeightEntryDialog({super.key, required this.cattle});
  final Cattle cattle;
  @override
  State<WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends State<WeightEntryDialog> {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => saving = true);
    try {
      final c = FarmScope.read(context).byId(widget.cattle.id) ?? widget.cattle;
      final n = double.parse(controller.text.trim().replaceAll(',', '.'));
      await FarmScope.read(context)
          .recordWeight(c.id, weightKg: n, source: 'manual');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !saving,
        child: AlertDialog(
          title: const Text('Catat bobot'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Masukkan hasil timbangan hari ini.'),
                const SizedBox(height: 16),
                TextFormField(
                  autofocus: true,
                  controller: controller,
                  enabled: !saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Bobot (kg)'),
                  validator: (v) {
                    final n = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    return n == null || !n.isFinite || n < 1 || n > 2000
                        ? 'Masukkan bobot 1–2.000 kg.'
                        : null;
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Menyimpan…' : 'Simpan bobot'),
            )
          ],
        ),
      );
}
