import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/form_save_error.dart';
import '../../widgets/livestock_labels.dart';
import '../../widgets/unsaved_changes_guard.dart';

class BeefRecordEditor extends StatefulWidget {
  const BeefRecordEditor({super.key, required this.cattle, required this.kind});
  final Cattle cattle;
  final BeefRecordKind kind;
  @override
  State<BeefRecordEditor> createState() => _BeefRecordEditorState();
}

class _BeefRecordEditorState extends State<BeefRecordEditor> {
  final form = GlobalKey<FormState>();
  final note = TextEditingController(),
      target = TextEditingController(),
      near = TextEditingController(),
      occurred = TextEditingController();
  BeefPurpose? purpose;
  BeefPhase? phase;
  PregnancyResult? pregnancy;
  String? sire, related, calf, error;
  bool dirty = false, busy = false;
  late String farmId;
  late List<Cattle> animals;
  @override
  void initState() {
    super.initState();
    final store = FarmScope.read(context);
    farmId = store.farmId;
    animals = store.allCattle;
    purpose = widget.cattle.modules.beef?.purpose;
    phase = widget.cattle.modules.beef?.phase;
    occurred.text = inputTime(store.currentTime.toLocal());
  }

  @override
  void dispose() {
    for (final c in [note, target, near, occurred]) {
      c.dispose();
    }
    super.dispose();
  }

  double? number(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FarmScope.read(context).recordBeef(widget.cattle.id,
          kind: widget.kind,
          note: note.text,
          occurredAt: parseInputTime(occurred.text)!,
          purpose: widget.kind == BeefRecordKind.purpose ? purpose : null,
          phase: widget.kind == BeefRecordKind.phase ? phase : null,
          targetKg:
              widget.kind == BeefRecordKind.target ? number(target.text) : null,
          nearKg: widget.kind == BeefRecordKind.target &&
                  near.text.trim().isNotEmpty
              ? number(near.text)
              : null,
          sireId: widget.kind == BeefRecordKind.service ? sire : null,
          relatedId: related,
          calfId: calf,
          pregnancy: pregnancy,
          expectedRevision: widget.cattle.modules.beef?.records.length ?? 0,
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

  Widget choice<T>(String label, T? value, Map<T, String> options,
          ValueChanged<T?> change, {bool required = true}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<T>(
              isExpanded: true,
              value: value,
              decoration: InputDecoration(labelText: label),
              items: options.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              validator: (v) => required && v == null ? 'Pilih $label.' : null,
              onChanged: change));
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final store = FarmScope.read(context), c = widget.cattle;
        final b = c.modules.beef;
        final kind = widget.kind;
        final editable = store.farmId == farmId &&
            store.byId(c.id)?.isActive == true &&
            store.byId(c.id)?.productionCategory == ProductionCategory.beef;
        final relatedOptions = {
          for (final r in b?.records ?? <BeefRecord>[])
            if (kind == BeefRecordKind.pregnancy &&
                    r.kind == BeefRecordKind.service ||
                kind == BeefRecordKind.calving &&
                    r.kind == BeefRecordKind.pregnancy &&
                    r.pregnancy == PregnancyResult.positive)
              r.id: '${dateLabel(r.occurredAt)} · ${r.note}'
        };
        return UnsavedChangesGuard(
            dirty: dirty,
            busy: busy,
            child: FarmPage(
                title: beefRecordLabels[kind]!,
                subtitle: c.nameOrId,
                back: true,
                children: [
                  const InfoBanner(
                      'Catatan manual, bukan diagnosis atau penentuan fase otomatis. Koreksi dicatat sebagai catatan baru; histori tetap tersimpan.'),
                  const SizedBox(height: 16),
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
                                    if (kind == BeefRecordKind.purpose)
                                      choice(
                                          'Tujuan Beef',
                                          purpose,
                                          beefPurposeLabels,
                                          (v) => setState(() => purpose = v)),
                                    if (kind == BeefRecordKind.phase)
                                      choice(
                                          'Fase Beef',
                                          phase,
                                          beefPhaseLabels,
                                          (v) => setState(() => phase = v)),
                                    if (kind == BeefRecordKind.target) ...[
                                      TextFormField(
                                          key: const ValueKey('beef-target'),
                                          controller: target,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                              labelText: 'Target bobot (kg)'),
                                          validator: (v) =>
                                              number(v ?? '') == null
                                                  ? 'Isi angka target.'
                                                  : null),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                          key: const ValueKey('beef-near'),
                                          controller: near,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                              labelText:
                                                  'Batas mendekati target (kg, opsional)'),
                                          validator: (v) =>
                                              v!.trim().isNotEmpty &&
                                                      number(v) == null
                                                  ? 'Isi angka yang valid.'
                                                  : null),
                                      const Text(
                                          'Batas ini ditentukan sendiri oleh pengguna, bukan standar kesiapan jual.'),
                                    ],
                                    if (kind == BeefRecordKind.service)
                                      choice(
                                          'Pejantan terdaftar (opsional)',
                                          sire,
                                          {
                                            for (final a in animals)
                                              if (a.gender == 'Jantan' &&
                                                  a.id != c.id)
                                                a.id: a.nameOrId
                                          },
                                          (v) => setState(() => sire = v),
                                          required: false),
                                    if (kind == BeefRecordKind.pregnancy ||
                                        kind == BeefRecordKind.calving)
                                      choice(
                                          kind == BeefRecordKind.pregnancy
                                              ? 'Breeding terkait'
                                              : 'Pemeriksaan positif terkait',
                                          related,
                                          relatedOptions,
                                          (v) => setState(() => related = v)),
                                    if (kind == BeefRecordKind.pregnancy)
                                      choice(
                                          'Hasil pemeriksaan manual',
                                          pregnancy,
                                          pregnancyLabels,
                                          (v) => setState(() => pregnancy = v)),
                                    if (kind == BeefRecordKind.calving) ...[
                                      choice(
                                          'Profil anak terdaftar (opsional)',
                                          calf,
                                          {
                                            for (final a in animals)
                                              if (a.isActive && a.id != c.id)
                                                a.id: a.nameOrId
                                          },
                                          (v) => setState(() => calf = v),
                                          required: false),
                                      const Text(
                                          'Hubungkan profil anak yang sudah ada. Tidak membuat umur atau tanggal lahir buatan. Jika profil belum tersedia, catat kelahiran tanpa tautan.'),
                                    ],
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        key: const ValueKey('beef-occurred'),
                                        controller: occurred,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Waktu kejadian lokal (YYYY-MM-DD HH:mm)'),
                                        validator: (v) =>
                                            parseInputTime(v ?? '') == null
                                                ? 'Waktu tidak valid.'
                                                : null),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        key: const ValueKey('beef-note'),
                                        controller: note,
                                        maxLength: 2000,
                                        maxLines: 3,
                                        decoration: const InputDecoration(
                                            labelText: 'Catatan / alasan'),
                                        validator: (v) => v!.trim().isEmpty
                                            ? 'Catatan diperlukan.'
                                            : null),
                                  ])))),
                  if (!editable)
                    const InfoBanner(
                        'Profil berubah atau nonaktif. Buka kembali profil untuk melanjutkan.',
                        warning: true),
                  if (error != null) FormSaveError(message: error!),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: busy || !editable ? null : save,
                      child: Text(busy ? 'Menyimpan…' : 'Simpan catatan Beef')),
                ]));
      });
}
