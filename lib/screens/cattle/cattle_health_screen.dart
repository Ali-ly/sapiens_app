import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/form_save_error.dart';
import '../../widgets/livestock_labels.dart';
import '../../widgets/unsaved_changes_guard.dart';

class CattleHealthScreen extends StatelessWidget {
  const CattleHealthScreen({super.key, required this.cattleId});
  final String cattleId;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final c = FarmScope.read(context).byId(cattleId);
        if (c == null) {
          return const FarmPage(
              title: 'Profil tidak tersedia',
              subtitle: 'Kembali ke daftar ternak.',
              back: true,
              children: []);
        }
        final records = c.core.health.reversed.toList();
        return FarmPage(
            title: 'Catatan kesehatan',
            subtitle: c.nameOrId,
            back: true,
            children: [
              FilledButton.icon(
                  onPressed: !c.isActive
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  CattleHealthEditorScreen(cattleId: c.id))),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah catatan kesehatan')),
              if (!c.isActive)
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                        'Profil nonaktif: histori dapat dibaca, penambahan catatan dinonaktifkan.')),
              const SizedBox(height: 18),
              if (records.isEmpty)
                const EmptyPanel(
                    title: 'Belum ada catatan kesehatan',
                    message: 'Catatan akan muncul setelah kamu menyimpannya.'),
              ...records.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(healthKindLabel(r.kind),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                            'Kejadian: ${timestampLabel(r.occurredAt, r.occurredAtText)}'),
                        Text(
                            'Dicatat: ${timestampLabel(r.recordedAt, r.recordedAtText)}'),
                        const SizedBox(height: 8),
                        Text(r.note),
                        if (r.nextDueAt != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  'Jadwal berikutnya: ${timestampLabel(r.nextDueAt!, r.nextDueAtText)}')),
                      ])))),
            ]);
      });
}

class CattleHealthEditorScreen extends StatefulWidget {
  const CattleHealthEditorScreen({super.key, required this.cattleId});
  final String cattleId;
  @override
  State<CattleHealthEditorScreen> createState() =>
      _CattleHealthEditorScreenState();
}

class _CattleHealthEditorScreenState extends State<CattleHealthEditorScreen> {
  final form = GlobalKey<FormState>();
  final note = TextEditingController(),
      occurred = TextEditingController(),
      due = TextEditingController();
  late final String farmAtOpen;
  HealthKind kind = HealthKind.observation;
  bool busy = false, dirty = false;
  String? saveError;
  @override
  void initState() {
    super.initState();
    farmAtOpen = FarmScope.read(context).farmId;
    occurred.text = inputTime(FarmScope.read(context).currentTime.toLocal());
  }

  @override
  void dispose() {
    note.dispose();
    occurred.dispose();
    due.dispose();
    super.dispose();
  }

  Future<void> pickTime(TextEditingController target) async {
    final initial = parseInputTime(target.text) ??
        FarmScope.read(context).currentTime.toLocal();
    final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(initial.year - 100),
        lastDate: DateTime(initial.year + 100, 12, 31));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    setState(() {
      target.text = inputTime(
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
      dirty = true;
    });
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      saveError = null;
    });
    try {
      await FarmScope.read(context).recordHealth(widget.cattleId,
          kind: kind,
          occurredAt: parseInputTime(occurred.text)!,
          note: note.text.trim(),
          nextDueAt: due.text.trim().isEmpty ? null : parseInputTime(due.text),
          expectedFarmId: farmAtOpen);
      if (!mounted) return;
      dirty = false;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => saveError = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: FarmScope.read(context),
      builder: (context, _) {
        final editable = FarmScope.read(context).farmId == farmAtOpen &&
            FarmScope.read(context).byId(widget.cattleId)?.isActive == true;
        return UnsavedChangesGuard(
            dirty: dirty,
            busy: busy,
            child: FarmPage(
                title: 'Tambah catatan kesehatan',
                subtitle: 'Catat observasi atau tindakan yang dilakukan.',
                back: true,
                children: [
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
                                    DropdownButtonFormField<HealthKind>(
                                        isExpanded: true,
                                        key: const ValueKey('health-kind'),
                                        value: kind,
                                        decoration: const InputDecoration(
                                            labelText: 'Jenis catatan'),
                                        items: HealthKind.values
                                            .map((k) => DropdownMenuItem(
                                                value: k,
                                                child:
                                                    Text(healthKindLabel(k))))
                                            .toList(),
                                        onChanged: busy || !editable
                                            ? null
                                            : (v) => setState(() {
                                                  kind = v!;
                                                  dirty = true;
                                                })),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        key: const ValueKey('health-occurred'),
                                        controller: occurred,
                                        enabled: !busy && editable,
                                        keyboardType: TextInputType.datetime,
                                        decoration: InputDecoration(
                                            labelText: 'Waktu kejadian',
                                            helperText:
                                                'YYYY-MM-DD HH:mm · waktu lokal perangkat',
                                            suffixIcon: IconButton(
                                                tooltip: 'Pilih waktu kejadian',
                                                onPressed: busy || !editable
                                                    ? null
                                                    : () => pickTime(occurred),
                                                icon: const Icon(Icons.event))),
                                        validator: (text) {
                                          final parsed =
                                              parseInputTime(text ?? '');
                                          return parsed == null
                                              ? 'Isi tanggal dan jam yang valid.'
                                              : parsed.isAfter(
                                                      FarmScope.read(context)
                                                          .currentTime)
                                                  ? 'Kejadian tidak boleh di masa depan.'
                                                  : null;
                                        }),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        key: const ValueKey('health-note'),
                                        controller: note,
                                        enabled: !busy && editable,
                                        maxLines: 4,
                                        maxLength: 2000,
                                        decoration: const InputDecoration(
                                            labelText: 'Observasi / tindakan'),
                                        validator: (v) =>
                                            v == null || v.trim().isEmpty
                                                ? 'Catatan wajib diisi.'
                                                : null),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        key: const ValueKey('health-due'),
                                        controller: due,
                                        enabled: !busy && editable,
                                        keyboardType: TextInputType.datetime,
                                        decoration: InputDecoration(
                                            labelText:
                                                'Jadwal berikutnya (opsional)',
                                            helperText:
                                                'YYYY-MM-DD HH:mm · kosongkan jika belum ada',
                                            suffixIcon: IconButton(
                                                tooltip:
                                                    'Pilih jadwal berikutnya',
                                                onPressed: busy || !editable
                                                    ? null
                                                    : () => pickTime(due),
                                                icon: const Icon(Icons.event))),
                                        validator: (text) {
                                          if (text == null ||
                                              text.trim().isEmpty) {
                                            return null;
                                          }
                                          final parsed = parseInputTime(text),
                                              at =
                                                  parseInputTime(occurred.text);
                                          return parsed == null
                                              ? 'Isi tanggal dan jam yang valid.'
                                              : at != null &&
                                                      parsed.isBefore(at)
                                                  ? 'Jadwal tidak boleh sebelum kejadian.'
                                                  : null;
                                        }),
                                  ])))),
                  if (!editable)
                    const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                            'Profil nonaktif atau tidak tersedia. Formulir hanya dapat dibaca.')),
                  if (saveError != null) FormSaveError(message: saveError!),
                  const SizedBox(height: 18),
                  FilledButton(
                      onPressed: busy || !editable ? null : save,
                      child: Text(
                          busy ? 'Menyimpan…' : 'Simpan catatan kesehatan')),
                  const SizedBox(height: 12),
                  const Text(
                      'Formulir ini menyimpan catatanmu, tanpa diagnosis atau rekomendasi obat otomatis.'),
                ]));
      });
}
