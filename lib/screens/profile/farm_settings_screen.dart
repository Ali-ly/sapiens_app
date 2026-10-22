import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/unsaved_changes_guard.dart';

class FarmSettingsScreen extends StatefulWidget {
  const FarmSettingsScreen({super.key});
  @override
  State<FarmSettingsScreen> createState() => _FarmSettingsScreenState();
}

class _FarmSettingsScreenState extends State<FarmSettingsScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, farm;
  late int days;
  bool busy = false, dirty = false;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: FarmScope.read(context).farmer);
    farm = TextEditingController(text: FarmScope.read(context).farm);
    days = FarmScope.read(context).reminderDays;
  }

  @override
  void dispose() {
    name.dispose();
    farm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      await FarmScope.read(context)
          .settings(name.text.trim(), farm.text.trim(), days);
      if (mounted) {
        dirty = false;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferensi peternakan tersimpan.')),
        );
      }
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
          title: 'Identitas & preferensi',
          subtitle: 'Detail kecil yang membuat pencatatan lebih personal.',
          back: true,
          eyebrow: 'PENGATURAN PETERNAKAN',
          children: [
            Panel(
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
                    TextFormField(
                      controller: name,
                      enabled: !busy,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Nama pemilik',
                        prefixIcon: Icon(CupertinoIcons.person),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nama wajib diisi.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: farm,
                      enabled: !busy,
                      maxLength: 70,
                      decoration: const InputDecoration(
                        labelText: 'Nama peternakan',
                        prefixIcon: Icon(CupertinoIcons.house),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nama peternakan wajib diisi.'
                          : null,
                    )
                  ],
                ),
              ),
            ),
            const SectionHeading('Kapan bobot perlu dicek?'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    value: days,
                    decoration: const InputDecoration(
                      labelText: 'Interval pengecekan',
                    ),
                    items: [3, 7, 14, 30]
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text('Setiap $d hari'),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(
                              () {
                                days = v!;
                                dirty = true;
                              },
                            ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pengingat muncul di dalam aplikasi. Rencana pakan dari bobot yang sudah perlu dicek tidak dimasukkan ke rekap bahan terkini.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Menyimpan…' : 'Simpan preferensi'),
            )
          ],
        ),
      );
}
