import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../models/dairy/dairy_calendar.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/form_save_error.dart';
import '../../widgets/unsaved_changes_guard.dart';
import 'dairy_record_editor.dart';

class MilkEditor extends StatefulWidget {
  const MilkEditor(
      {super.key, required this.cattle, this.existing, this.initialDay});
  final Cattle cattle;
  final MilkRecord? existing;
  final String? initialDay;
  @override
  State<MilkEditor> createState() => _MilkEditorState();
}

class _MilkEditorState extends State<MilkEditor> {
  final form = GlobalKey<FormState>();
  final day = TextEditingController(),
      total = TextEditingController(),
      am = TextEditingController(),
      pm = TextEditingController(),
      note = TextEditingController(),
      quality = TextEditingController();
  MilkMode mode = MilkMode.daily;
  String? error;
  bool busy = false, dirty = false;
  late String farmId;
  @override
  void initState() {
    super.initState();
    farmId = FarmScope.read(context).farmId;
    final old = widget.existing;
    day.text = old?.day ??
        widget.initialDay ??
        DairyCalendar.day(FarmScope.read(context).currentTime.toLocal());
    if (old != null) {
      mode = old.mode;
      total.text = old.total?.toString() ?? '';
      am.text = old.am?.toString() ?? '';
      pm.text = old.pm?.toString() ?? '';
      quality.text = old.qualityNote;
    }
  }

  @override
  void dispose() {
    for (final c in [day, total, am, pm, note, quality]) {
      c.dispose();
    }
    super.dispose();
  }

  double? number(TextEditingController c) => c.text.trim().isEmpty
      ? null
      : double.tryParse(c.text.trim().replaceAll(',', '.'));
  Widget volume(String label, String key, TextEditingController c) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          key: ValueKey(key),
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          validator: (v) => v!.trim().isNotEmpty && number(c) == null
              ? 'Isi angka liter.'
              : null));
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FarmScope.read(context).recordMilk(widget.cattle.id,
          day: day.text.trim(),
          mode: mode,
          note: note.text,
          total: mode == MilkMode.daily ? number(total) : null,
          am: mode == MilkMode.amPm ? number(am) : null,
          pm: mode == MilkMode.amPm ? number(pm) : null,
          qualityNote: quality.text,
          supersedesId: widget.existing?.id,
          expectedRevision: widget.cattle.modules.dairy?.revision ?? 0,
          expectedFarmId: farmId);
      if (!mounted) return;
      dirty = false;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final s = FarmScope.read(context), c = s.byId(widget.cattle.id);
        final editable = s.farmId == farmId &&
            c?.isActive == true &&
            c?.productionCategory == ProductionCategory.dairy &&
            c?.gender == 'Betina';
        return UnsavedChangesGuard(
            dirty: dirty,
            busy: busy,
            child: FarmPage(
                title: widget.existing == null
                    ? 'Catat susu'
                    : 'Koreksi catatan susu',
                subtitle: widget.cattle.nameOrId,
                back: true,
                children: [
                  const InfoBanner(
                      'Satu snapshot per tanggal: total harian ATAU AM + PM. Kosong berarti belum dicatat; angka 0 berarti produksi nol yang Anda catat. Koreksi menyimpan histori lama.'),
                  const SizedBox(height: 12),
                  Panel(
                      child: AbsorbPointer(
                          absorbing: busy || !editable,
                          child: Form(
                              key: form,
                              onChanged: () => setState(() => dirty = true),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                        key: const ValueKey('milk-day'),
                                        controller: day,
                                        readOnly: widget.existing != null,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Tanggal pemerahan (YYYY-MM-DD)'),
                                        validator: dairyDayError),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<MilkMode>(
                                        isExpanded: true,
                                        value: mode,
                                        decoration: const InputDecoration(
                                            labelText: 'Mode pencatatan'),
                                        items: milkModeLabels.entries
                                            .map((e) => DropdownMenuItem(
                                                value: e.key,
                                                child: Text(e.value)))
                                            .toList(),
                                        onChanged: (v) =>
                                            setState(() => mode = v!)),
                                    const SizedBox(height: 16),
                                    if (mode == MilkMode.daily)
                                      volume('Total harian (liter)',
                                          'milk-total', total)
                                    else ...[
                                      volume(
                                          'AM / pagi (liter)', 'milk-am', am),
                                      volume('PM / sore (liter)', 'milk-pm', pm)
                                    ],
                                    TextFormField(
                                        key: const ValueKey('milk-note'),
                                        controller: note,
                                        maxLength: 2000,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Catatan / alasan koreksi'),
                                        validator: (v) => v!.trim().isEmpty
                                            ? 'Catatan diperlukan.'
                                            : null),
                                    TextFormField(
                                        controller: quality,
                                        maxLength: 2000,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Catatan kualitas manual (opsional)')),
                                  ])))),
                  if (!editable)
                    const InfoBanner(
                        'Pencatatan susu memerlukan profil Dairy betina yang aktif.',
                        warning: true),
                  if (error != null) FormSaveError(message: error!),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: busy || !editable ? null : save,
                      child: Text(busy ? 'Menyimpan…' : 'Simpan susu')),
                ]));
      });
}
