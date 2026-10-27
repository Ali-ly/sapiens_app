import '../cattle.dart';
import '../farm_snapshot.dart';
import '../twin_rules.dart';
import 'dairy_calendar.dart';

class DairyRules {
  static void validate(FarmSnapshot farm) {
    final animals = {for (final c in farm.cattle) c.id: c};
    final ids = <String>{
      farm.farmId,
      ...animals.keys,
      ...farm.feedStock.map((r) => r.id),
      ...farm.feedPlans.map((r) => r.id),
      ...farm.groups.map((r) => r.id),
      ...farm.groups.expand((g) => g.history).map((r) => r.id),
      ...farm.groupFeedPlans.map((r) => r.id),
      ...farm.legacyMemberships.map((r) => r.id),
      ...farm.cattle.expand((c) => [
            ...c.history.map((r) => r.id).whereType<String>(),
            ...c.images.map((r) => r.id).whereType<String>(),
            ...c.core.health.map((r) => r.id),
            ...c.core.timeline.map((r) => r.id),
            ...c.core.photos.history.map((r) => r.id),
            ...c.core.lifecycle.statuses.map((r) => r.id),
            ...c.core.lifecycle.stages.map((r) => r.id),
            ...?c.modules.beef?.records.map((r) => r.id)
          ])
    };
    final calves = {
      for (final c in farm.cattle)
        for (final r in c.modules.beef?.records ?? <BeefRecord>[])
          if (r.calfId != null) r.calfId!
    };
    final allDaily = <String, double>{};
    for (final c in farm.cattle) {
      final d = c.modules.dairy;
      if (d == null) continue;
      TwinRules.ordered(d.records.map((r) => r.recordedAt));
      TwinRules.ordered(d.milk.map((r) => r.recordedAt));
      final prior = <String, DairyRecord>{},
          checks = <String, DairyRecord>{},
          holds = <String, DairyRecord>{};
      final closed = <String>{};
      DairyRecord? lastCalving;
      var cycleCount = 0;
      for (final r in d.records) {
        if (r.id.trim().isEmpty ||
            !ids.add(r.id) ||
            r.note.trim().isEmpty ||
            r.note.length > 2000) fail('Identitas/catatan Dairy tidak valid.');
        DairyRecord.fromJson(r.toJson());
        DairyCalendar.captured(r.recordedAt, r.recordedOn);
        DairyCalendar.parse(r.day);
        if (r.kind != DairyRecordKind.withholding &&
                r.day.compareTo(r.recordedOn) > 0 ||
            r.confirmedConception && r.kind != DairyRecordKind.pregnancy) {
          fail('Tanggal/jenis catatan Dairy tidak valid.');
        }
        switch (r.kind) {
          case DairyRecordKind.phase:
            if (r.phase == null) fail('Pilih fase Dairy.');
          case DairyRecordKind.service:
            if (c.gender != 'Betina' ||
                lastCalving != null && r.day.compareTo(lastCalving.day) < 0 ||
                r.sireId != null &&
                    (r.sireId == c.id ||
                        animals[r.sireId]?.gender != 'Jantan')) {
              fail('Breeding/referensi pejantan tidak valid.');
            }
          case DairyRecordKind.pregnancy:
            final service = prior[r.relatedId];
            if (c.gender != 'Betina' ||
                service?.kind != DairyRecordKind.service ||
                r.pregnancy == null ||
                r.day.compareTo(service!.day) < 0 ||
                closed.contains(service.id) ||
                lastCalving != null &&
                    service.day.compareTo(lastCalving.day) < 0 ||
                r.confirmedConception &&
                    r.pregnancy != PregnancyResult.positive) {
              fail(
                  'Pemeriksaan harus merujuk breeding terbuka; konfirmasi konsepsi hanya untuk hasil positif.');
            }
            checks[service.id] = r;
          case DairyRecordKind.calving:
            if (c.gender != 'Betina' ||
                lastCalving != null && r.day.compareTo(lastCalving.day) <= 0) {
              fail(
                  'Tanggal calving harus meningkat; jangan gandakan kelahiran pada tanggal yang sama.');
            }
            String? sire;
            if (r.relatedId != null) {
              final check = prior[r.relatedId];
              final service = prior[check?.relatedId];
              if (check?.kind != DairyRecordKind.pregnancy ||
                  check?.pregnancy != PregnancyResult.positive ||
                  service == null ||
                  checks[service.id]?.id != check!.id ||
                  r.day.compareTo(check.day) < 0 ||
                  !closed.add(service.id) ||
                  lastCalving != null &&
                      service.day.compareTo(lastCalving.day) < 0) {
                fail(
                    'Calving memerlukan pemeriksaan positif terbaru untuk breeding yang belum ditutup.');
              }
              sire = service.sireId;
            }
            cycleCount++;
            if (r.parity != null &&
                    (r.parity! < cycleCount ||
                        lastCalving?.parity != null &&
                            r.parity != lastCalving!.parity! + 1) ||
                lastCalving?.parity != null && r.parity == null) {
              fail(
                  'Nomor laktasi harus konsisten dengan calving tercatat dan baseline pengguna.');
            }
            if (r.calfId != null) {
              final calf = animals[r.calfId];
              if (calf == null ||
                  calf.id == c.id ||
                  !calves.add(calf.id) ||
                  calf.core.references.damId != c.id ||
                  sire != null && calf.core.references.sireId != sire) {
                fail('Relasi induk/pejantan/anak Dairy tidak valid.');
              }
            }
            // Calving closes earlier breeding, including records already entered
            // on that civil date. A later-dated service can predate entry of a
            // historical calving and still belong to the new cycle.
            closed.addAll(prior.values
                .where((p) =>
                    p.kind == DairyRecordKind.service &&
                    p.day.compareTo(r.day) <= 0)
                .map((p) => p.id));
            lastCalving = r;
          case DairyRecordKind.udder:
            if (r.healthRecordId != null &&
                !c.core.health.any((h) => h.id == r.healthRecordId)) {
              fail('Catatan kesehatan terkait tidak tersedia pada sapi ini.');
            }
          case DairyRecordKind.withholding:
            if (c.gender != 'Betina' ||
                r.safeUseDay == null ||
                DairyCalendar.days(r.day, r.safeUseDay!) <= 0) {
              fail('Tanggal tinjau kembali harus sesudah awal masa tahan.');
            }
            if (r.supersedesId != null &&
                holds.remove(r.supersedesId) == null) {
              fail('Koreksi harus merujuk masa tahan aktif.');
            }
            holds[r.id] = r;
        }
        prior[r.id] = r;
      }
      final days = <String, MilkRecord>{};
      for (final m in d.milk) {
        MilkRecord.fromJson(m.toJson());
        DairyCalendar.captured(m.recordedAt, m.recordedOn);
        DairyCalendar.parse(m.day);
        if (c.gender != 'Betina' ||
            m.id.trim().isEmpty ||
            !ids.add(m.id) ||
            m.note.trim().isEmpty ||
            m.note.length > 2000 ||
            m.qualityNote.length > 2000 ||
            m.day.compareTo(m.recordedOn) > 0) {
          fail('Identitas, tanggal atau catatan susu tidak valid.');
        }
        final values = [m.total, m.am, m.pm].whereType<double>();
        if (values.isEmpty ||
            values.any((v) => !v.isFinite || v < 0) ||
            !m.recordedLiters.isFinite ||
            m.mode == MilkMode.daily &&
                (m.total == null || m.am != null || m.pm != null) ||
            m.mode == MilkMode.amPm && m.total != null) {
          fail(
              'Isi total harian ATAU sesi AM/PM; volume harus finite dan nonnegatif.');
        }
        final old = days[m.day];
        if (old == null ? m.supersedesId != null : m.supersedesId != old.id) {
          fail(
              'Tanggal susu sudah tercatat. Koreksi harus mengganti snapshot terakhir secara eksplisit.');
        }
        days[m.day] = m;
      }
      for (final m in days.values) {
        final sum = (allDaily[m.day] ?? 0) + m.recordedLiters;
        if (!sum.isFinite) fail('Total susu harian melampaui kapasitas angka.');
        allDaily[m.day] = sum;
      }
    }
  }

  static Never fail(String message) => throw FormatException(message);
}
