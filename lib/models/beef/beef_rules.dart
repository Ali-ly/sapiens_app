import '../cattle.dart';
import '../cattle_rules.dart';
import '../farm_snapshot.dart';
import '../feed_plan.dart';
import '../feed_stock.dart';
import '../twin_rules.dart';

class BeefRules {
  static void validate(FarmSnapshot farm) {
    final byId = {for (final c in farm.cattle) c.id: c};
    final ids = <String>{
      farm.farmId,
      ...byId.keys,
      ...farm.feedPlans.map((p) => p.id),
      ...farm.groups.map((g) => g.id),
      ...farm.groups.expand((g) => g.history).map((r) => r.id),
      ...farm.legacyMemberships.map((r) => r.id),
      ...farm.groupFeedPlans.map((p) => p.id),
      ...farm.cattle.expand((c) => [
            ...c.history.map((r) => r.id).whereType<String>(),
            ...c.images.map((r) => r.id).whereType<String>(),
            ...c.core.timeline.map((r) => r.id),
            ...c.core.health.map((r) => r.id),
            ...c.core.photos.history.map((r) => r.id),
            ...c.core.lifecycle.statuses.map((r) => r.id),
            ...c.core.lifecycle.stages.map((r) => r.id)
          ])
    };
    final calves = <String>{};
    for (final c in farm.cattle) {
      final records = c.modules.beef?.records ?? <BeefRecord>[];
      TwinRules.ordered(records.map((r) => r.recordedAt));
      final prior = <String, BeefRecord>{};
      final closedServices = <String>{};
      BeefPurpose? purpose;
      for (final r in records) {
        if (r.id.trim().isEmpty ||
            !ids.add(r.id) ||
            r.note.trim().isEmpty ||
            r.note.length > 2000 ||
            r.occurredAt.isAfter(r.recordedAt)) {
          _fail('Identitas, catatan, atau waktu Beef tidak valid.');
        }
        // Round-trip strict shape also rejects extraneous fields on constructed records.
        BeefRecord.fromJson(r.toJson());
        switch (r.kind) {
          case BeefRecordKind.purpose:
            if (r.purpose == null) _fail('Tujuan Beef wajib dipilih.');
            purpose = r.purpose;
          case BeefRecordKind.phase:
            if (purpose == null || r.phase == null) {
              _fail('Pilih tujuan sebelum fase Beef.');
            }
          case BeefRecordKind.target:
            if (purpose == null ||
                r.targetKg == null ||
                !r.targetKg!.isFinite ||
                r.targetKg! <= 0 ||
                r.targetKg! > CattleRules.maximumWeight ||
                r.nearKg != null &&
                    (!r.nearKg!.isFinite ||
                        r.nearKg! <= 0 ||
                        r.nearKg! >= r.targetKg!)) {
              _fail(
                  'Target harus positif; batas mendekati target harus di bawah target.');
            }
          case BeefRecordKind.service:
            if (purpose != BeefPurpose.breeding || c.gender != 'Betina') {
              _fail('Reproduksi hanya untuk induk betina Pembibitan.');
            }
            if (r.sireId != null &&
                (byId[r.sireId]?.gender != 'Jantan' || r.sireId == c.id)) {
              _fail('Referensi pejantan tidak valid.');
            }
          case BeefRecordKind.pregnancy:
            final service = prior[r.relatedId];
            if (purpose != BeefPurpose.breeding ||
                c.gender != 'Betina' ||
                r.pregnancy == null ||
                service?.kind != BeefRecordKind.service ||
                r.occurredAt.isBefore(service!.occurredAt) ||
                closedServices.contains(service.id)) {
              _fail('Pemeriksaan harus merujuk breeding yang belum selesai.');
            }
          case BeefRecordKind.calving:
            final check = prior[r.relatedId];
            final service = prior[check?.relatedId];
            if (purpose != BeefPurpose.breeding ||
                c.gender != 'Betina' ||
                check?.kind != BeefRecordKind.pregnancy ||
                check?.pregnancy != PregnancyResult.positive ||
                service == null ||
                r.occurredAt.isBefore(check!.occurredAt) ||
                !closedServices.add(service.id)) {
              _fail(
                  'Kelahiran harus merujuk pemeriksaan positif yang belum ditutup.');
            }
            final checks = prior.values
                .where((p) =>
                    p.kind == BeefRecordKind.pregnancy &&
                    p.relatedId == service.id)
                .toList();
            if (checks.isEmpty || checks.last.id != check.id) {
              _fail(
                  'Gunakan pemeriksaan kebuntingan terkini untuk breeding ini.');
            }
            if (r.calfId != null) {
              final calf = byId[r.calfId];
              if (calf == null ||
                  calf.id == c.id ||
                  !calves.add(calf.id) ||
                  calf.core.references.damId != c.id ||
                  service.sireId != null &&
                      calf.core.references.sireId != service.sireId) {
                _fail(
                    'Relasi induk, pejantan, atau anak tidak sesuai kelahiran.');
              }
            }
        }
        prior[r.id] = r;
      }
    }
    TwinRules.ordered(farm.feedStock.map((e) => e.recordedAt));
    final balances = <String, double>{};
    for (final e in farm.feedStock) {
      if (e.id.trim().isEmpty ||
          !ids.add(e.id) ||
          !feedLabels.containsKey(e.feed) ||
          !e.kg.isFinite ||
          e.kg == 0 ||
          e.kind != StockMovement.correction && e.kg < 0 ||
          e.note.trim().isEmpty ||
          e.note.length > 2000) {
        _fail('Catatan stok tidak valid (kg pakan segar).');
      }
      final balance = (balances[e.feed] ?? 0) + e.delta;
      if (!balance.isFinite || balance < 0) {
        _fail('Stok tidak boleh negatif pada setiap transaksi.');
      }
      balances[e.feed] = balance;
    }
  }

  static Never _fail(String message) => throw FormatException(message);
}
