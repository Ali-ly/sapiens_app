import 'cattle.dart';
import 'cattle_rules.dart';
import 'farm_snapshot.dart';

/// Structural integrity only; no scientific age/weight/clinical thresholds.
class TwinRules {
  static void validate(FarmSnapshot farm,
      {bool requireStableIdentity = false}) {
    if (requireStableIdentity && farm.farmId.trim().isEmpty) {
      _fail('ID farm tidak tersedia.');
    }
    final stableIds = <String>{};
    final cattleIds = farm.cattle.map((c) => c.id).toSet();
    final names = <String>{};
    if (cattleIds.length != farm.cattle.length) _fail('ID sapi duplikat.');
    for (final c in farm.cattle) {
      CattleRules.validate(c);
      c.core.identity.ageEvidence.validate();
      if (!names.add(c.nameOrId.trim().toLowerCase())) {
        _fail('Nama sapi duplikat.');
      }
      final category = c.productionCategory;
      if (category != null &&
          farm.productionSystems != null &&
          !farm.productionSystems!.allows(category)) {
        _fail('Kategori sapi tidak sesuai sistem produksi peternakan.');
      }
      final refs = c.core.references;
      for (final id in [refs.damId, refs.sireId]) {
        if (id != null && (id == c.id || !cattleIds.contains(id))) {
          _fail('Referensi induk tidak valid.');
        }
      }
      if (refs.damId != null && refs.damId == refs.sireId) {
        _fail('Referensi induk duplikat.');
      }
      if (refs.externalIds.entries
          .any((e) => e.key.trim().isEmpty || e.value.trim().isEmpty)) {
        _fail('Referensi eksternal kosong.');
      }
      final ids = <String>{};
      final weights = <String>{},
          photos = <String>{},
          statuses = <String>{},
          stages = <String>{},
          health = <String>{};
      void add(String id, Set<String> type) {
        if (id.trim().isEmpty || !ids.add(id)) {
          _fail('ID histori Twin kosong atau duplikat.');
        }
        type.add(id);
      }

      for (final r in c.history) {
        if (requireStableIdentity && (r.id == null || !stableIds.add(r.id!))) {
          _fail('ID bobot hilang atau duplikat.');
        }
        if (r.id != null) add(r.id!, weights);
      }
      for (final image in c.images) {
        if (requireStableIdentity &&
            (image.id == null ||
                image.id!.trim().isEmpty ||
                !stableIds.add(image.id!))) {
          _fail('ID media hilang atau duplikat.');
        }
      }
      ordered(c.core.lifecycle.statuses.map((r) => r.recordedAt));
      for (final r in c.core.lifecycle.statuses) {
        add(r.id, statuses);
        note(r.note);
      }
      ordered(c.core.lifecycle.stages.map((r) => r.recordedAt));
      for (final r in c.core.lifecycle.stages) {
        add(r.id, stages);
        note(r.note);
      }
      ordered(c.core.health.map((r) => r.recordedAt));
      for (final r in c.core.health) {
        add(r.id, health);
        note(r.note);
        if (r.note.trim().isEmpty ||
            r.occurredAt.isAfter(r.recordedAt) ||
            r.nextDueAt != null && r.nextDueAt!.isBefore(r.occurredAt)) {
          _fail('Waktu catatan kesehatan tidak valid.');
        }
      }
      ordered(c.core.photos.history.map((r) => r.recordedAt));
      final indices = <int>{};
      for (final r in c.core.photos.history) {
        add(r.id, photos);
        if (requireStableIdentity &&
            (r.mediaId == null ||
                r.imageIndex < 0 ||
                r.imageIndex >= c.images.length ||
                r.mediaId != c.images[r.imageIndex].id)) {
          _fail('Referensi identitas media tidak valid.');
        }
        if (r.imageIndex < 0 ||
            r.imageIndex >= c.images.length ||
            !indices.add(r.imageIndex) ||
            !{'ai', 'manual'}.contains(r.source) ||
            r.weightRecordId != null && !weights.contains(r.weightRecordId)) {
          _fail('Referensi histori foto tidak valid.');
        }
      }
      ordered(c.core.timeline.map((r) => r.recordedAt));
      ProductionCategory? lastCategory;
      var hasCategoryEvent = false;
      for (final r in c.core.timeline) {
        add(r.id, <String>{});
        note(r.note);
        final allowed = switch (r.kind) {
          TwinEventKind.weightRecorded => weights,
          TwinEventKind.photosAdded => photos,
          TwinEventKind.statusChanged => statuses,
          TwinEventKind.lifeStageChanged => stages,
          TwinEventKind.healthRecorded => health,
          TwinEventKind.productionCategoryChanged => <String>{},
        };
        if (r.kind == TwinEventKind.productionCategoryChanged) {
          if (r.recordId != null ||
              r.productionCategory == null ||
              r.productionCategory == r.previousCategory ||
              r.note.trim().isEmpty ||
              hasCategoryEvent && r.previousCategory != lastCategory) {
            _fail('Referensi perubahan kategori tidak valid.');
          }
          hasCategoryEvent = true;
          lastCategory = r.productionCategory;
        } else if (!allowed.contains(r.recordId) ||
            r.productionCategory != null ||
            r.previousCategory != null) {
          _fail('Referensi timeline tidak valid.');
        }
      }
      if (hasCategoryEvent && lastCategory != c.productionCategory) {
        _fail('Kategori terkini tidak sesuai timeline.');
      }
    }
    // Parent links form a DAG; importing a cycle would make future genealogy unsafe.
    final visiting = <String>{}, done = <String>{};
    final byId = {for (final c in farm.cattle) c.id: c};
    void visit(String id) {
      if (done.contains(id)) return;
      if (!visiting.add(id)) _fail('Referensi induk membentuk siklus.');
      final refs = byId[id]!.core.references;
      for (final parent in [refs.damId, refs.sireId]) {
        if (parent != null) visit(parent);
      }
      visiting.remove(id);
      done.add(id);
    }

    for (final id in cattleIds) {
      visit(id);
    }
  }

  static void ordered(Iterable<DateTime> dates) {
    DateTime? previous;
    for (final date in dates) {
      if (previous != null && date.isBefore(previous)) {
        _fail('Histori Twin tidak berurutan.');
      }
      previous = date;
    }
  }

  static void note(String text) {
    if (text.length > 2000) _fail('Catatan Twin terlalu panjang.');
  }

  static Never _fail(String message) => throw FormatException(message);
}
