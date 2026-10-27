import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../models/dairy/dairy_calendar.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/form_save_error.dart';
import '../../widgets/unsaved_changes_guard.dart';
import '../cattle/cattle_health_screen.dart';

String? dairyDayError(String? value) {
  try {
    DairyCalendar.parse(value?.trim() ?? '');
    return null;
  } catch (_) {
    return 'Tanggal harus valid: YYYY-MM-DD.';
  }
}

class DairyRecordEditor extends StatefulWidget {
  const DairyRecordEditor(
      {super.key, required this.cattle, required this.kind});
  final Cattle cattle;
  final DairyRecordKind kind;
  @override
  State<DairyRecordEditor> createState() => _DairyRecordEditorState();
}

class _DairyRecordEditorState extends State<DairyRecordEditor> {
  final form = GlobalKey<FormState>();
  final day = TextEditingController(),
      note = TextEditingController(),
      number = TextEditingController(),
      safe = TextEditingController();
  DairyPhase? phase;
  PregnancyResult? pregnancy;
  String? related, sire, calf, health, supersedes, error;
  bool confirmed = false, dirty = false, busy = false;
  late String farmId;
  late List<Cattle> animals;
  @override
  void initState() {
    super.initState();
    final s = FarmScope.read(context);
    farmId = s.farmId;
    animals = s.allCattle;
    day.text = DairyCalendar.day(s.currentTime.toLocal());
    phase = widget.cattle.modules.dairy?.phase;
  }

  @override
  void dispose() {
    for (final c in [day, note, number, safe]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget choice<T>(String label, T? value, Map<T, String> options,
          ValueChanged<T?> change, {bool required = false}) =>
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
              onChanged: change,
              validator: (v) =>
                  required && v == null ? 'Pilih $label.' : null));
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FarmScope.read(context).recordDairy(widget.cattle.id,
          kind: widget.kind,
          day: day.text.trim(),
          note: note.text,
          phase: widget.kind == DairyRecordKind.phase ? phase : null,
          sireId: sire,
          relatedId: related,
          calfId: calf,
          pregnancy: pregnancy,
          confirmedConception: confirmed,
          parity:
              number.text.trim().isEmpty ? null : int.parse(number.text.trim()),
          safeUseDay: widget.kind == DairyRecordKind.withholding
              ? safe.text.trim()
              : null,
          supersedesId: supersedes,
          healthRecordId: health,
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
        final s = FarmScope.read(context),
            c = widget.cattle,
            d = c.modules.dairy ?? const DairyExtension(),
            k = widget.kind;
        final current = s.byId(c.id);
        final editable = s.farmId == farmId &&
            current?.isActive == true &&
            current?.productionCategory == ProductionCategory.dairy &&
            (k == DairyRecordKind.phase ||
                k == DairyRecordKind.udder ||
                current?.gender == 'Betina');
        final records = d.records;
        final checks = {
          for (final r in records)
            if (r.kind == DairyRecordKind.pregnancy && r.relatedId != null)
              r.relatedId!: r
        };
        final birth = d.calvings.lastOrNull;
        final closed = {
          for (final r in d.calvings)
            for (final check in records)
              if (check.id == r.relatedId) check.relatedId
        };
        final services = records.where((r) =>
            r.kind == DairyRecordKind.service &&
            !closed.contains(r.id) &&
            (birth == null ||
                r.day.compareTo(birth.day) > 0 ||
                r.day == birth.day &&
                    records.indexOf(r) > records.indexOf(birth)));
        final links = k == DairyRecordKind.pregnancy
            ? services
            : checks.values.where((r) =>
                r.pregnancy == PregnancyResult.positive &&
                services.any((s) => s.id == r.relatedId));
        return UnsavedChangesGuard(
            dirty: dirty,
            busy: busy,
            child: FarmPage(
                title: dairyRecordLabels[k]!,
                subtitle: c.nameOrId,
                back: true,
                children: [
                  const InfoBanner(
                      'Input manual, bukan diagnosis. Fase tidak ditentukan otomatis dari umur atau DIM. Histori dipertahankan.'),
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
                                    if (k == DairyRecordKind.phase)
                                      choice(
                                          'Fase Dairy',
                                          phase,
                                          dairyPhaseLabels,
                                          (v) => setState(() => phase = v),
                                          required: true),
                                    if (k == DairyRecordKind.service)
                                      choice(
                                          'Pejantan terdaftar (opsional)',
                                          sire,
                                          {
                                            for (final a in animals)
                                              if (a.gender == 'Jantan' &&
                                                  a.id != c.id)
                                                a.id: a.nameOrId
                                          },
                                          (v) => setState(() => sire = v)),
                                    if (k == DairyRecordKind.pregnancy ||
                                        k == DairyRecordKind.calving)
                                      choice(
                                          k == DairyRecordKind.pregnancy
                                              ? 'Breeding terkait'
                                              : 'Pemeriksaan positif (opsional)',
                                          related,
                                          {
                                            for (final r in links)
                                              r.id: '${r.day} · ${r.note}'
                                          },
                                          (v) => setState(() => related = v),
                                          required:
                                              k == DairyRecordKind.pregnancy),
                                    if (k == DairyRecordKind.pregnancy) ...[
                                      choice(
                                          'Hasil manual',
                                          pregnancy,
                                          {
                                            PregnancyResult.positive: 'Positif',
                                            PregnancyResult.negative:
                                                'Tidak bunting',
                                            PregnancyResult.inconclusive:
                                                'Belum pasti'
                                          },
                                          (v) => setState(() {
                                                pregnancy = v;
                                                if (v !=
                                                    PregnancyResult.positive) {
                                                  confirmed = false;
                                                }
                                              }),
                                          required: true),
                                      if (pregnancy == PregnancyResult.positive)
                                        CheckboxListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text(
                                                'Saya mengonfirmasi breeding terkait sebagai konsepsi'),
                                            subtitle: const Text(
                                                'Diperlukan untuk Days Open dan Services per Conception. Tanggal pemeriksaan tidak dianggap tanggal konsepsi.'),
                                            value: confirmed,
                                            onChanged: (v) => setState(
                                                () => confirmed = v ?? false)),
                                    ],
                                    if (k == DairyRecordKind.calving) ...[
                                      const Text(
                                          'Calving membuat siklus laktasi baru. Tanpa histori breeding, catat kelahiran aktual sebagai baseline; jangan mengarang pregnancy event.'),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                          key: const ValueKey('dairy-parity'),
                                          controller: number,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                              labelText:
                                                  'Nomor laktasi/paritas diketahui (opsional)',
                                              hintText: birth?.parity == null
                                                  ? 'Kosongkan bila tidak diketahui'
                                                  : 'Berikutnya ${birth!.parity! + 1}'),
                                          validator: (v) => v!
                                                      .trim()
                                                      .isNotEmpty &&
                                                  int.tryParse(v.trim()) == null
                                              ? 'Isi bilangan bulat.'
                                              : null),
                                      const SizedBox(height: 12),
                                      choice(
                                          'Profil anak existing (opsional)',
                                          calf,
                                          {
                                            for (final a in animals)
                                              if (a.isActive && a.id != c.id)
                                                a.id: a.nameOrId
                                          },
                                          (v) => setState(() => calf = v)),
                                      const Text(
                                          'Tidak membuat profil pedet dengan umur/DOB buatan. Kelahiran tetap dapat dicatat tanpa tautan anak.'),
                                    ],
                                    if (k == DairyRecordKind.udder) ...[
                                      choice(
                                          'Shared Health terkait (opsional)',
                                          health,
                                          {
                                            for (final r
                                                in current?.core.health ??
                                                    <HealthRecord>[])
                                              r.id: r.note
                                          },
                                          (v) => setState(() => health = v)),
                                      TextButton(
                                          onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      CattleHealthScreen(
                                                          cattleId: c.id))),
                                          child: const Text(
                                              'Buka catatan kesehatan')),
                                      const Text(
                                          'Observasi ambing/susu tidak otomatis menahan susu. Bila perlu, catat masa tahan sesuai arahan yang Anda miliki.'),
                                    ],
                                    if (k == DairyRecordKind.withholding) ...[
                                      choice(
                                          'Koreksi masa tahan aktif (opsional)',
                                          supersedes,
                                          {
                                            for (final r in d.holds)
                                              r.id:
                                                  '${r.day} → ${r.safeUseDay} · ${r.note}'
                                          },
                                          (v) =>
                                              setState(() => supersedes = v)),
                                      const Text(
                                          'Tanggal mulai inklusif; tanggal tinjau kembali eksklusif. Masukkan dari pengguna/vet/label, bukan perkiraan aplikasi. Catatan ini bukan jaminan susu aman.'),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                          key: const ValueKey('dairy-safe-day'),
                                          controller: safe,
                                          decoration: const InputDecoration(
                                              labelText:
                                                  'Tanggal tinjau/safe-use dari sumber (YYYY-MM-DD)'),
                                          validator: dairyDayError),
                                    ],
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        key: const ValueKey('dairy-day'),
                                        controller: day,
                                        decoration: InputDecoration(
                                            labelText: k ==
                                                    DairyRecordKind.withholding
                                                ? 'Mulai masa tahan (YYYY-MM-DD)'
                                                : 'Tanggal kejadian (YYYY-MM-DD)'),
                                        validator: dairyDayError),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        key: const ValueKey('dairy-note'),
                                        controller: note,
                                        maxLength: 2000,
                                        maxLines: 3,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Catatan / alasan / sumber'),
                                        validator: (v) => v!.trim().isEmpty
                                            ? 'Catatan diperlukan.'
                                            : null),
                                  ])))),
                  if (!editable)
                    const InfoBanner(
                        'Edit memerlukan profil Dairy aktif; produksi/reproduksi induk memerlukan profil betina.',
                        warning: true),
                  if (error != null) FormSaveError(message: error!),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: busy || !editable ? null : save,
                      child:
                          Text(busy ? 'Menyimpan…' : 'Simpan catatan Dairy')),
                ]));
      });
}
