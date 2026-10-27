import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/farm_controller.dart';
import '../../application/providers.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';
import '../care/condition_fields.dart';
import '../weight/weight_entry.dart';
import 'profile_page.dart';

class AddCattlePage extends ConsumerStatefulWidget {
  const AddCattlePage({super.key});
  @override
  ConsumerState<AddCattlePage> createState() => _AddCattlePageState();
}

class _AddCattlePageState extends ConsumerState<AddCattlePage> {
  final identity = GlobalKey<FormState>(),
      condition = GlobalKey<ConditionFieldsState>();
  final name = TextEditingController(),
      userId = TextEditingController(),
      age = TextEditingController();
  late final FarmAccount account;
  late Sex sex;
  WeightInput? weight;
  int step = 0;
  bool dirty = false;
  @override
  void initState() {
    super.initState();
    account = ref.read(farmProvider).requireValue.account!;
    sex = account.mode == FarmMode.beef ? Sex.male : Sex.female;
  }

  @override
  void dispose() {
    name.dispose();
    userId.dispose();
    age.dispose();
    super.dispose();
  }

  Future<void> save() async {
    require(weight != null,
        'Bobot awal wajib. Isi hasil timbangan atau selesaikan estimasi foto.');
    final context = condition.currentState?.read();
    require(context != null, 'Lengkapi konteks sapi setelah bobot tersedia.');
    final id = await ref.read(farmProvider.notifier).createCattle(
        name: name.text,
        userId: userId.text,
        sex: sex,
        ageMonths: int.parse(age.text),
        condition: context!,
        initialWeight: weight!,
        expectedAccountId: account.id,
        expectedMode: account.mode);
    if (!mounted) return;
    setState(() => dirty = false);
    Navigator.of(this.context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => CattleProfilePage(cattleId: id)));
  }

  @override
  Widget build(BuildContext context) => DraftGuard(
      dirty: dirty,
      child: PageFrame(
          title: 'Tambah Sapi',
          subtitle: '${account.mode.label} · Langkah ${step + 1} dari 2',
          children: [
            LinearProgressIndicator(value: (step + 1) / 2),
            const SizedBox(height: 24),
            Visibility(
                visible: step == 0,
                maintainState: true,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Heading('Kenali sapi barumu'),
                      Form(
                          key: identity,
                          onChanged: () {
                            if (!dirty) setState(() => dirty = true);
                          },
                          child: Column(children: [
                            TextFormField(
                                key: const ValueKey('cattle-name'),
                                controller: name,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 80,
                                decoration: const InputDecoration(
                                    labelText: 'Nama sapi'),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Nama sapi wajib diisi.'
                                    : null),
                            const SizedBox(height: 14),
                            TextFormField(
                                key: const ValueKey('cattle-user-id'),
                                controller: userId,
                                maxLength: 80,
                                decoration: const InputDecoration(
                                    labelText: 'ID sapi (opsional)',
                                    helperText:
                                        'Nomor tag atau penanda yang kamu gunakan.')),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<Sex>(
                                value: sex,
                                decoration: const InputDecoration(
                                    labelText: 'Jenis kelamin'),
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
                                key: const ValueKey('cattle-age'),
                                controller: age,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Umur (bulan)',
                                    helperText:
                                        'Isi umur yang diketahui. 0 untuk belum berusia satu bulan.'),
                                validator: (v) => int.tryParse(v ?? '') ==
                                            null ||
                                        int.parse(v!) < 0
                                    ? 'Masukkan umur dalam bulan, nol atau lebih.'
                                    : null),
                          ])),
                      const SizedBox(height: 24),
                      FilledButton(
                          key: const ValueKey('cattle-next'),
                          onPressed: () {
                            if (identity.currentState!.validate()) {
                              FocusScope.of(context).unfocus();
                              setState(() => step = 1);
                            }
                          },
                          child: const Text('Lanjut: bobot & kondisi')),
                    ])),
            Visibility(
                visible: step == 1,
                maintainState: true,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Heading('Bobot awal wajib'),
                      const Text(
                          'Setiap sapi dimulai dengan satu catatan bobot. Foto yang lolos estimasi akan masuk ke galeri.'),
                      const SizedBox(height: 16),
                      WeightEntry(
                          onChanged: (v) => setState(() {
                                weight = v;
                                dirty = true;
                              })),
                      if (weight != null) ...[
                        const Heading('Kondisi pemeliharaan'),
                        Surface(
                            child: ConditionFields(
                                key: condition,
                                mode: account.mode,
                                sex: sex,
                                onChanged: () => dirty = true))
                      ],
                      const SizedBox(height: 20),
                      SubmitButton(
                          key: const ValueKey('cattle-save'),
                          label: 'Simpan Sapi',
                          submit: save),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: () => setState(() => step = 0),
                          child: const Text('Kembali ke identitas')),
                    ])),
          ]));
}
