import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/unsaved_changes_guard.dart';
import 'cattle_profile_screen.dart';

class AddCattleScreen extends StatefulWidget {
  const AddCattleScreen({super.key, this.cattle});
  final Cattle? cattle;
  @override
  State<AddCattleScreen> createState() => _AddCattleScreenState();
}

class _AddCattleScreenState extends State<AddCattleScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, age, notes;
  final weight = TextEditingController();
  late String gender;
  bool busy = false, dirty = false;
  @override
  void initState() {
    super.initState();
    final c = widget.cattle;
    name = TextEditingController(text: c?.nameOrId);
    age = TextEditingController(text: c?.ageMonths.toString());
    notes = TextEditingController(text: c?.notes);
    gender = c?.gender ?? 'Jantan';
  }

  @override
  void dispose() {
    for (final c in [name, age, notes, weight]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    try {
      final old = widget.cattle;
      final kg = double.tryParse(weight.text.replaceAll(',', '.'));
      final saved = old != null
          ? await FarmScope.read(context).updateIdentity(
              old.id,
              name: name.text,
              gender: gender,
              ageMonths: int.parse(age.text.trim()),
              notes: notes.text,
            )
          : await FarmScope.read(context).saveCattle(
              Cattle(
                nameOrId: name.text.trim(),
                gender: gender,
                ageMonths: int.parse(age.text.trim()),
                notes: notes.text.trim(),
                estimatedWeight: kg,
                history: kg == null
                    ? []
                    : [
                        WeightRecord(
                          weightKg: kg,
                          date: DateTime.now(),
                          source: 'manual',
                        )
                      ],
              ),
            );
      if (!mounted) {
        return;
      }
      dirty = false;
      final messenger = ScaffoldMessenger.of(context);
      if (old == null) {
        Navigator.pushReplacement<void, void>(
          context,
          MaterialPageRoute(
            builder: (_) => CattleProfileScreen(cattle: saved),
          ),
        );
      } else {
        Navigator.pop(context);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            old == null
                ? 'Sapi ditambahkan. Catat bobot lalu hitung pakannya.'
                : 'Identitas sapi diperbarui.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
        dirty: dirty,
        busy: busy,
        child: FarmPage(
          title: widget.cattle == null ? 'Tambah sapi' : 'Edit profil sapi',
          subtitle: 'Identitas yang rapi, pemantauan lebih mudah.',
          back: true,
          children: [
            Panel(
              child: AbsorbPointer(
                absorbing: busy,
                child: Form(
                  key: form,
                  onChanged: () {
                    if (!dirty) {
                      setState(() => dirty = true);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'IDENTITAS SAPI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          labelText: 'Nama / ID sapi',
                          hintText: 'Contoh: B006 - Raka',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Nama / ID sapi wajib diisi.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: age,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Umur (bulan)',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 1 || n > 360
                              ? 'Masukkan umur 1–360 bulan.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 18),
                      const Text('Jenis kelamin'),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Jantan',
                            label: Text('Jantan'),
                            icon: Icon(Icons.male),
                          ),
                          ButtonSegment(
                            value: 'Betina',
                            label: Text('Betina'),
                            icon: Icon(Icons.female),
                          ),
                        ],
                        selected: {gender},
                        onSelectionChanged: busy
                            ? null
                            : (s) => setState(
                                  () {
                                    gender = s.first;
                                    dirty = true;
                                  },
                                ),
                      ),
                      const SizedBox(height: 20),
                      if (widget.cattle == null) ...[
                        TextFormField(
                          controller: weight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Bobot awal (kg, opsional)',
                            helperText: 'Kosongkan jika belum ditimbang.',
                            prefixIcon: Icon(Icons.monitor_weight_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return null;
                            }
                            final w = double.tryParse(v.replaceAll(',', '.'));
                            return w == null || !w.isFinite || w < 1 || w > 2000
                                ? 'Masukkan bobot 1–2.000 kg.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                      TextFormField(
                        controller: notes,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                          hintText: 'Ras, asal ternak, atau kondisi khusus',
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: busy ? null : save,
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(busy ? 'Menyimpan…' : 'Simpan sapi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Setelah disimpan, kamu langsung masuk ke profil sapi untuk mencatat bobot dan menghitung kebutuhan pakan.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      );
}
