import 'package:flutter/material.dart';

import '../../models/cattle.dart';
import '../../state/farm_scope.dart';
import '../../widgets/farm_ui.dart';
import '../../widgets/form_save_error.dart';
import '../../widgets/livestock_labels.dart';
import '../../widgets/unsaved_changes_guard.dart';

enum CattleRecordEdit { category, status, lifeStage }

class CattleRecordEditorScreen extends StatefulWidget {
  const CattleRecordEditorScreen(
      {super.key, required this.cattle, required this.kind});
  final Cattle cattle;
  final CattleRecordEdit kind;
  @override
  State<CattleRecordEditorScreen> createState() =>
      _CattleRecordEditorScreenState();
}

class _CattleRecordEditorScreenState extends State<CattleRecordEditorScreen> {
  final form = GlobalKey<FormState>();
  final note = TextEditingController();
  ProductionCategory? category;
  late CattleStatus status;
  LifeStage? stage;
  bool busy = false, dirty = false;
  String? saveError;
  late final FarmProductionSystems? systemsAtOpen;
  late final String farmRevision;
  late final String farmAtOpen;
  @override
  void initState() {
    super.initState();
    systemsAtOpen = FarmScope.read(context).productionSystems;
    farmRevision = FarmScope.read(context).settingsRevision;
    farmAtOpen = FarmScope.read(context).farmId;
    category = widget.cattle.productionCategory;
    status = widget.cattle.status;
    stage = widget.cattle.core.lifecycle.stage;
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  String get title => switch (widget.kind) {
        CattleRecordEdit.category => 'Kategori produksi',
        CattleRecordEdit.status => 'Ubah status ternak',
        CattleRecordEdit.lifeStage => 'Catat tahap hidup'
      };
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      saveError = null;
    });
    final store = FarmScope.read(context), c = widget.cattle;
    try {
      switch (widget.kind) {
        case CattleRecordEdit.category:
          await store.setProductionCategory(c.id, category!,
              reason: note.text.trim(),
              expectedEventCount: c.core.timeline.length,
              expectedFarmSettingsRevision: farmRevision);
        case CattleRecordEdit.status:
          await store.setCattleStatus(c.id, status,
              note: note.text.trim(),
              expectedEventCount: c.core.timeline.length,
              expectedFarmId: farmAtOpen);
        case CattleRecordEdit.lifeStage:
          await store.recordLifeStage(c.id, stage!,
              note: note.text.trim(),
              expectedEventCount: c.core.timeline.length,
              expectedFarmId: farmAtOpen);
      }
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
        final systems = systemsAtOpen;
        final current = FarmScope.read(context).byId(widget.cattle.id);
        final editable = FarmScope.read(context).farmId == farmAtOpen &&
            current != null &&
            (widget.kind == CattleRecordEdit.status || current.isActive);
        final unchanged = widget.kind == CattleRecordEdit.category &&
                category == widget.cattle.productionCategory ||
            widget.kind == CattleRecordEdit.status &&
                status == widget.cattle.status;
        return UnsavedChangesGuard(
            dirty: dirty,
            busy: busy,
            child: FarmPage(
                title: title,
                subtitle: widget.cattle.nameOrId,
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
                                    if (widget.kind ==
                                        CattleRecordEdit.category) ...[
                                      Text(
                                          'Saat ini: ${productionLabel(widget.cattle.productionCategory)}'),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<
                                              ProductionCategory>(
                                          isExpanded: true,
                                          key:
                                              const ValueKey('cattle-category'),
                                          value: category,
                                          decoration: const InputDecoration(
                                              labelText: 'Kategori sapi'),
                                          items: ProductionCategory.values
                                              .where((c) =>
                                                  systems == null ||
                                                  systems.allows(c))
                                              .map((c) => DropdownMenuItem(
                                                  value: c,
                                                  child:
                                                      Text(productionLabel(c))))
                                              .toList(),
                                          onChanged: busy || !editable
                                              ? null
                                              : (value) => setState(() {
                                                    category = value;
                                                    dirty = true;
                                                  }),
                                          validator: (value) => value == null
                                              ? 'Pilih kategori sapi.'
                                              : null),
                                      const SizedBox(height: 12),
                                      const Text(
                                          'Perubahan dapat memengaruhi konteks fitur berikutnya. Histori serta namespace Beef/Dairy tetap disimpan. Sistem produksi farm tidak diubah otomatis.'),
                                    ],
                                    if (widget.kind ==
                                        CattleRecordEdit.status) ...[
                                      Text(
                                          'Saat ini: ${widget.cattle.status.label}'),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<CattleStatus>(
                                          isExpanded: true,
                                          key: const ValueKey('cattle-status'),
                                          value: status,
                                          decoration: const InputDecoration(
                                              labelText: 'Status baru'),
                                          items: CattleStatus.values
                                              .map((s) => DropdownMenuItem(
                                                  value: s,
                                                  child: Text(s.label)))
                                              .toList(),
                                          onChanged: busy || !editable
                                              ? null
                                              : (value) => setState(() {
                                                    status = value!;
                                                    dirty = true;
                                                  })),
                                      const SizedBox(height: 12),
                                      const Text(
                                          'Status nonaktif mengeluarkan sapi dari rekap operasional. Profil dan histori tetap tersimpan. Memilih Aktif kembali menambah catatan koreksi, tanpa menghapus status sebelumnya.'),
                                      const SizedBox(height: 12),
                                      const Text(
                                          'Waktu pencatatan diisi saat simpan. Tanggal efektif/backdate belum didukung.'),
                                    ],
                                    if (widget.kind ==
                                        CattleRecordEdit.lifeStage) ...[
                                      DropdownButtonFormField<LifeStage>(
                                          isExpanded: true,
                                          key: const ValueKey(
                                              'cattle-life-stage'),
                                          value: stage,
                                          decoration: const InputDecoration(
                                              labelText: 'Tahap hidup'),
                                          items: LifeStage.values
                                              .map((s) => DropdownMenuItem(
                                                  value: s,
                                                  child:
                                                      Text(lifeStageLabel(s))))
                                              .toList(),
                                          onChanged: busy || !editable
                                              ? null
                                              : (value) => setState(() {
                                                    stage = value;
                                                    dirty = true;
                                                  }),
                                          validator: (value) => value == null
                                              ? 'Pilih tahap hidup.'
                                              : null),
                                      const SizedBox(height: 12),
                                      const Text(
                                          'Pilihan manual berdasarkan catatanmu. Tidak ditentukan otomatis dari umur atau bobot.'),
                                    ],
                                    const SizedBox(height: 18),
                                    TextFormField(
                                        key: const ValueKey('record-note'),
                                        controller: note,
                                        enabled: !busy && editable,
                                        maxLines: 3,
                                        maxLength: 2000,
                                        decoration: InputDecoration(
                                            labelText: widget.kind ==
                                                    CattleRecordEdit.category
                                                ? 'Alasan klasifikasi/perubahan'
                                                : 'Catatan (opsional)'),
                                        validator: (text) => widget.kind ==
                                                    CattleRecordEdit.category &&
                                                (text == null ||
                                                    text.trim().isEmpty)
                                            ? 'Alasan wajib diisi.'
                                            : null),
                                  ])))),
                  if (!editable)
                    const Text(
                        'Profil nonaktif, tidak tersedia, atau data farm berubah. Formulir hanya dapat dibaca.'),
                  if (saveError != null) FormSaveError(message: saveError!),
                  const SizedBox(height: 18),
                  FilledButton(
                      onPressed: busy || !editable || unchanged ? null : save,
                      child: Text(busy ? 'Menyimpan…' : 'Simpan perubahan')),
                ]));
      });
}
