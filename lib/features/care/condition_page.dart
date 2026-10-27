import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../domain/cattle.dart';
import '../../ui/components.dart';
import 'condition_fields.dart';

class ConditionPage extends ConsumerStatefulWidget {
  const ConditionPage({super.key, required this.cattle});
  final Cattle cattle;
  @override
  ConsumerState<ConditionPage> createState() => _ConditionPageState();
}

class _ConditionPageState extends ConsumerState<ConditionPage> {
  final fields = GlobalKey<ConditionFieldsState>();
  bool dirty = false;
  @override
  Widget build(BuildContext context) {
    final account = ref.watch(farmProvider).requireValue.account!;
    return DraftGuard(
        dirty: dirty,
        child: PageFrame(
            title: 'Perbarui kondisi',
            subtitle: widget.cattle.name,
            children: [
              const Notice(
                  'Perubahan disimpan sebagai catatan baru. Evaluasi pakan sebelumnya akan perlu ditinjau ulang.'),
              Surface(
                  child: ConditionFields(
                      key: fields,
                      mode: account.mode,
                      sex: widget.cattle.sex,
                      initial: widget.cattle.condition,
                      advanced: true,
                      onChanged: () => setState(() => dirty = true))),
              SubmitButton(
                  label: 'Simpan kondisi',
                  submit: () async {
                    final value = fields.currentState!.read();
                    await ref.read(farmProvider.notifier).condition(
                        widget.cattle.id, value,
                        expectedCondition: widget.cattle.conditions.last.id);
                    if (context.mounted) {
                      dirty = false;
                      Navigator.pop(context);
                    }
                  }),
            ]));
  }
}
