import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../domain/cattle.dart';
import '../../domain/condition.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';

class EditIdentityPage extends ConsumerStatefulWidget {
  const EditIdentityPage({super.key, required this.cattle});
  final Cattle cattle;
  @override
  ConsumerState<EditIdentityPage> createState() => _EditIdentityPageState();
}

class _EditIdentityPageState extends ConsumerState<EditIdentityPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, userId, age;
  late Sex sex;
  DairyStage? stage;
  Pregnancy? pregnancy;
  bool dirty = false;
  @override
  void initState() {
    super.initState();
    final c = widget.cattle;
    name = TextEditingController(text: c.name);
    userId = TextEditingController(text: c.userId);
    age = TextEditingController(text: c.ageMonths.toString());
    sex = c.sex;
  }

  @override
  void dispose() {
    name.dispose();
    userId.dispose();
    age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.cattle.condition;
    final correcting = sex != widget.cattle.sex && sex == Sex.female;
    return DraftGuard(
        dirty: dirty,
        child: PageFrame(
            title: 'Edit Profil Sapi',
            subtitle:
                'Identitas dasar. Histori bobot, susu, dan kondisi tetap dipertahankan.',
            children: [
              Form(
                  key: form,
                  onChanged: () {
                    if (!dirty) setState(() => dirty = true);
                  },
                  child: Column(children: [
                    TextFormField(
                        controller: name,
                        maxLength: 80,
                        decoration:
                            const InputDecoration(labelText: 'Nama sapi'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Nama wajib diisi.'
                            : null),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: userId,
                        maxLength: 80,
                        decoration: const InputDecoration(
                            labelText: 'ID sapi (opsional)')),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<Sex>(
                        value: sex,
                        decoration:
                            const InputDecoration(labelText: 'Jenis kelamin'),
                        items: Sex.values
                            .map((v) => DropdownMenuItem(
                                value: v, child: Text(v.label)))
                            .toList(),
                        onChanged: (v) => setState(() {
                              sex = v!;
                              dirty = true;
                            })),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: age,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Umur (bulan)'),
                        validator: (v) =>
                            int.tryParse(v ?? '') == null || int.parse(v!) < 0
                                ? 'Masukkan umur yang valid.'
                                : null),
                    if (correcting && current is DairyCondition) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<DairyStage>(
                          value: stage,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Fase fisiologis yang benar'),
                          items: DairyStage.values
                              .map((v) => DropdownMenuItem(
                                  value: v, child: Text(v.label)))
                              .toList(),
                          onChanged: (v) => stage = v,
                          validator: (v) =>
                              v == null ? 'Pilih fase yang benar.' : null)
                    ],
                    if (correcting &&
                        current is BeefCondition &&
                        current.purpose == BeefPurpose.breeding) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<Pregnancy>(
                          value: pregnancy,
                          decoration: const InputDecoration(
                              labelText: 'Status reproduksi'),
                          items: Pregnancy.values
                              .map((v) => DropdownMenuItem(
                                  value: v, child: Text(v.label)))
                              .toList(),
                          onChanged: (v) => pregnancy = v,
                          validator: (v) =>
                              v == null ? 'Pilih status reproduksi.' : null)
                    ],
                  ])),
              const SizedBox(height: 24),
              SubmitButton(
                  label: 'Simpan identitas',
                  submit: () async {
                    if (!form.currentState!.validate()) return;
                    await ref.read(farmProvider.notifier).identity(
                        widget.cattle.id,
                        name: name.text,
                        userId: userId.text,
                        sex: sex,
                        ageMonths: int.parse(age.text),
                        correctedStage: stage,
                        correctedPregnancy: pregnancy);
                    if (context.mounted) {
                      dirty = false;
                      Navigator.pop(context);
                    }
                  }),
            ]));
  }
}
