import 'package:flutter/material.dart';
import '../../domain/condition.dart';
import '../../domain/value.dart';
import '../../ui/components.dart';

class ConditionFields extends StatefulWidget {
  const ConditionFields(
      {super.key,
      required this.mode,
      required this.sex,
      this.initial,
      this.advanced = false,
      this.onChanged});
  final FarmMode mode;
  final Sex sex;
  final Condition? initial;
  final bool advanced;
  final VoidCallback? onChanged;
  @override
  State<ConditionFields> createState() => ConditionFieldsState();
}

class ConditionFieldsState extends State<ConditionFields> {
  BeefPurpose? purpose;
  FatteningPhase? phase;
  Pregnancy? pregnancy;
  DairyStage? stage;
  bool? isHeifer;
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  TextEditingController control(String name) =>
      fields.putIfAbsent(name, () => TextEditingController());
  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    void fill(String k, Object? v) {
      if (v != null) control(k).text = v.toString();
    }

    if (c is BeefCondition) {
      purpose = c.purpose;
      phase = c.phase;
      pregnancy = c.pregnancy;
      fill('adg', c.targetAdg);
      fill('gestation', c.gestationMonth);
    }
    if (c is DairyCondition) {
      stage = c.stage;
      isHeifer = c.isHeifer;
      fill('parity', c.parity);
      fill('bcs', c.bcs);
      fill('fat', c.milkFat);
      fill('protein', c.milkProtein);
      fill('lactose', c.milkLactose);
      fill('weeks', c.weeksToCalving);
      fill('ndf', c.rationNdf);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget choice<T>(String label, T? value, List<T> values,
          String Function(T) text, ValueChanged<T?> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<T>(
              value: value,
              isExpanded: true,
              itemHeight: null,
              decoration: InputDecoration(labelText: label),
              items: values
                  .map((v) => DropdownMenuItem(value: v, child: Text(text(v))))
                  .toList(),
              onChanged: (v) {
                setState(() => change(v));
                widget.onChanged?.call();
              },
              validator: (v) => v == null ? 'Pilih $label.' : null));
  Widget optional(String key, String label,
          {String? helper, bool integer = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              key: ValueKey('context-$key'),
              controller: control(key),
              keyboardType: TextInputType.numberWithOptions(decimal: !integer),
              decoration: InputDecoration(labelText: label, helperText: helper),
              onChanged: (_) => widget.onChanged?.call(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = numeric(v);
                return n == null ||
                        !n.isFinite ||
                        n < 0 ||
                        integer && (int.tryParse(v) == null || n == 0)
                    ? 'Masukkan angka yang valid.'
                    : null;
              }));
  Condition read() {
    require(form.currentState?.validate() == true, 'Lengkapi kondisi sapi.');
    double? n(String k) => numeric(control(k).text);
    final Condition value;
    if (widget.mode == FarmMode.beef) {
      require(purpose != null, 'Pilih tujuan pemeliharaan.');
      value = BeefCondition(
          purpose: purpose!,
          phase: purpose == BeefPurpose.fattening ? phase : null,
          pregnancy: purpose == BeefPurpose.breeding && widget.sex == Sex.female
              ? pregnancy
              : null,
          targetAdg: purpose == BeefPurpose.fattening ? n('adg') : null,
          gestationMonth:
              pregnancy == Pregnancy.pregnant ? n('gestation') : null);
    } else {
      value = widget.sex == Sex.male
          ? const DairyCondition()
          : DairyCondition(
              stage: stage,
              parity: int.tryParse(control('parity').text),
              bcs: n('bcs'),
              milkFat: n('fat'),
              milkProtein: n('protein'),
              milkLactose: n('lactose'),
              weeksToCalving: stage == DairyStage.closeUp ? n('weeks') : null,
              rationNdf: stage == DairyStage.closeUp ? n('ndf') : null,
              isHeifer: stage == DairyStage.closeUp ? isHeifer : null);
    }
    validateCondition(value, widget.mode, widget.sex);
    return value;
  }

  @override
  Widget build(BuildContext context) => Form(
      key: form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.mode == FarmMode.beef) ...[
          choice('Tujuan pemeliharaan', purpose, BeefPurpose.values,
              (v) => v.label, (v) {
            purpose = v;
            phase = null;
            pregnancy = null;
          }),
          if (purpose == BeefPurpose.fattening)
            choice('Fase penggemukan', phase, FatteningPhase.values,
                (v) => v.label, (v) => phase = v),
          if (purpose == BeefPurpose.breeding && widget.sex == Sex.female)
            choice('Status reproduksi', pregnancy, Pregnancy.values,
                (v) => v.label, (v) => pregnancy = v),
          if (widget.advanced && purpose == BeefPurpose.fattening)
            optional('adg', 'Target kenaikan berat per hari (kg)',
                helper:
                    'Target yang kamu pilih; diperlukan untuk evaluasi pakan.'),
          if (widget.advanced && pregnancy == Pregnancy.pregnant)
            optional('gestation', 'Umur kebuntingan (bulan, bila diketahui)'),
        ] else if (widget.sex == Sex.female) ...[
          choice('Fase fisiologis', stage, DairyStage.values, (v) => v.label,
              (v) => stage = v),
          if (widget.advanced) ...[
            optional('parity', 'Nomor laktasi / paritas, bila diketahui',
                integer: true,
                helper:
                    'Kosongkan bila belum pasti. Tidak dihitung dari umur.'),
            if (stage?.lactating == true)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Data nutrisi susu'),
                  subtitle: const Text(
                      'Isi dari pengukuran; tidak diberi nilai default.'),
                  children: [
                    optional('fat', 'Lemak susu (%)'),
                    optional('protein', 'Protein susu (%)'),
                    optional('lactose', 'Laktosa susu (%)'),
                    optional('bcs', 'BCS manual (1–5)')
                  ]),
            if (stage == DairyStage.closeUp) ...[
              optional('weeks', 'Minggu menuju kelahiran'),
              optional('ndf', 'NDF ransum (% bahan kering)'),
              choice(
                  'Dara belum pernah beranak?',
                  isHeifer,
                  const [true, false],
                  (v) => v ? 'Ya, dara' : 'Tidak',
                  (v) => isHeifer = v)
            ],
          ],
        ] else
          const Notice(
              'Sapi perah jantan tidak memakai fase laktasi, produksi susu, atau reproduksi betina.'),
      ]));
}
