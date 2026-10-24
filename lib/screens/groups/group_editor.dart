import 'package:flutter/material.dart';

import '../../models/cattle_rules.dart';
import '../../models/feed_plan.dart';
import '../../models/livestock_group.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';

Future<LivestockGroup?> showGroupEditor(BuildContext context,
        {LivestockGroup? group}) =>
    showDialog<LivestockGroup>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _GroupEditor(group: group));

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({this.group});
  final LivestockGroup? group;
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.group?.name);
  late final notes = TextEditingController(text: widget.group?.notes);
  late final count =
      TextEditingController(text: widget.group?.headCount.toString());
  late final average =
      TextEditingController(text: widget.group?.averageWeightKg?.toString());
  late String target = widget.group?.target ?? 'pemeliharaan';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    count.dispose();
    average.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final store = FarmScope.read(context);
    try {
      final current = widget.group;
      final LivestockGroup result;
      if (current == null) {
        result = await store.createGroup(name.text,
            notes: notes.text,
            headCount: int.parse(count.text.trim()),
            averageWeightKg:
                double.tryParse(average.text.trim().replaceAll(',', '.')),
            target: target);
      } else {
        await store.updateGroup(current.id,
            name: name.text,
            notes: notes.text,
            headCount: int.parse(count.text.trim()),
            averageWeightKg:
                double.tryParse(average.text.trim().replaceAll(',', '.')),
            target: target);
        result = store.groupById(current.id)!;
      }
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorMessage(e);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(widget.group == null
            ? 'Buat kelompok/kandang'
            : 'Edit kelompok/kandang'),
        content: SingleChildScrollView(
            child: Form(
                key: form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      controller: name,
                      enabled: !busy,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Nama kelompok/kandang'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Isi nama kelompok/kandang.'
                              : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: count,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Jumlah sapi',
                          helperText: 'Boleh 0 untuk kandang kosong.'),
                      validator: (value) {
                        final n = int.tryParse(value?.trim() ?? '');
                        return n == null || n < 0 || n > 1000000
                            ? 'Isi jumlah sapi bulat antara 0 dan 1.000.000.'
                            : null;
                      }),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: average,
                      enabled: !busy,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Bobot rata-rata (kg)',
                          helperText: 'Isi untuk menghitung pakan kelompok.'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final n =
                            double.tryParse(value.trim().replaceAll(',', '.'));
                        return n == null || !CattleRules.isValidWeight(n)
                            ? 'Bobot antara 1 dan 2.000 kg.'
                            : null;
                      }),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      value: target,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Target pemeliharaan'),
                      items: targetLabels.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() => target = value!)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: notes,
                      enabled: !busy,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'Catatan kelompok (opsional)')),
                  if (error != null)
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ]))),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Menyimpan…' : 'Simpan kelompok')),
        ],
      ));
}
