import 'cattle.dart';
import 'condition.dart';
import 'records.dart';
import 'value.dart';

void validateFarm(FarmData data) {
  require(data.revision >= 0, 'Revisi tidak valid.');
  require(data.account != null || data.cattle.isEmpty,
      'Pilih mode peternakan sebelum membuat sapi.');
  final ids = <String>{};
  void unique(String id) =>
      require(id.isNotEmpty && ids.add(id), 'ID catatan kosong atau duplikat.');
  if (data.account != null) {
    unique(data.account!.id);
    require(
        data.account!.owner.trim().isNotEmpty &&
            data.account!.farmName.trim().isNotEmpty,
        'Identitas peternakan wajib diisi.');
  }
  final userIds = <String>{};
  for (final c in data.cattle) {
    unique(c.id);
    require(
        c.name.trim().isNotEmpty &&
            c.name.length <= 80 &&
            c.userId.length <= 80 &&
            c.ageMonths >= 0,
        'Identitas sapi tidak valid.');
    require(
        c.userId.trim().isEmpty || userIds.add(c.userId.trim().toLowerCase()),
        'ID sapi sudah digunakan.');
    require(c.weights.isNotEmpty && c.conditions.isNotEmpty,
        'Bobot awal dan kondisi wajib sebelum sapi disimpan.');
    require(!c.updatedAt.isBefore(c.createdAt),
        'Waktu pembaruan sapi tidak valid.');
    DateTime? previous;
    final weightIds = <String>{}, photoIds = <String>{};
    for (final w in c.weights) {
      unique(w.id);
      weightIds.add(w.id);
      positive(w.kg, 'Bobot');
      require(previous == null || !w.measuredAt.isBefore(previous),
          'Urutan pengukuran bobot tidak valid.');
      previous = w.measuredAt;
    }
    for (final p in c.photos) {
      unique(p.id);
      photoIds.add(p.id);
      require(
          p.name.isNotEmpty &&
              p.bytes.isNotEmpty &&
              (p.weightId == null || weightIds.contains(p.weightId)),
          'Referensi foto tidak valid.');
    }
    for (final w in c.weights) {
      require(
          w.photoIds.toSet().length == w.photoIds.length &&
              w.photoIds.every(photoIds.contains),
          'Foto pengukuran tidak ditemukan.');
      for (final id in w.photoIds) {
        require(c.photos.firstWhere((p) => p.id == id).weightId == w.id,
            'Hubungan foto dan pengukuran tidak sesuai.');
      }
    }
    previous = null;
    for (final r in c.conditions) {
      unique(r.id);
      require(
          (data.account!.mode == FarmMode.beef && r.value is BeefCondition) ||
              (data.account!.mode == FarmMode.dairy &&
                  r.value is DairyCondition),
          'Kondisi dari mode lain tidak dapat digabung.');
      require(previous == null || !r.effectiveAt.isBefore(previous),
          'Urutan kondisi tidak valid.');
      previous = r.effectiveAt;
    }
    validateCondition(c.condition, data.account!.mode, c.sex);
    require(
        data.account!.mode == FarmMode.dairy ||
            c.milk.isEmpty && c.events.isEmpty,
        'Catatan susu/reproduksi perah tidak sesuai mode akun.');
    final currentMilk = <String, MilkRecord>{};
    for (final m in c.milk) {
      unique(m.id);
      calendar(m.date);
      if (m.mode == MilkMode.totalDaily) {
        require(m.total != null && m.am == null && m.pm == null,
            'Satu hari memakai satu mode pemerahan.');
      } else {
        require(m.total == null && (m.am != null || m.pm != null),
            'Isi minimal satu sesi susu.');
      }
      for (final v in [m.total, m.am, m.pm]) {
        if (v != null) positive(v, 'Produksi susu', zero: true);
      }
      require(m.correctionOf == currentMilk[m.date]?.id,
          'Koreksi harus mengacu catatan aktif pada tanggal yang sama.');
      currentMilk[m.date] = m;
    }
    final eventIds = <String, DairyEvent>{};
    String? lastCalving;
    int? parity;
    for (final e in c.events) {
      unique(e.id);
      calendar(e.date);
      require(e.note.length <= 1000, 'Catatan terlalu panjang.');
      if (e.kind == DairyEventKind.pregnancyCheck) {
        require(e.pregnancy != null, 'Pilih hasil pemeriksaan manual.');
      }
      if (e.kind == DairyEventKind.confirmedConception) {
        require(
            e.relatedId != null &&
                eventIds[e.relatedId]?.kind == DairyEventKind.service &&
                eventIds[e.relatedId]!.date.compareTo(e.date) <= 0,
            'Pilih catatan IB yang mendasari konsepsi.');
      }
      if (e.kind == DairyEventKind.withholding) {
        require(
            e.until != null &&
                calendar(e.until!).compareTo(calendar(e.date)) >= 0,
            'Isi tanggal akhir masa tahan dari pengguna/vet/label.');
      }
      if (e.kind == DairyEventKind.calving) {
        require(lastCalving == null || e.date.compareTo(lastCalving) > 0,
            'Kelahiran baru harus setelah kelahiran sebelumnya.');
        require(
            e.parity == null || e.parity! > 0, 'Nomor laktasi harus positif.');
        require(parity == null || e.parity == parity + 1,
            'Nomor laktasi setelah kelahiran harus bertambah satu.');
        lastCalving = e.date;
        parity = e.parity;
      }
      eventIds[e.id] = e;
    }
    for (final e in c.evaluations) {
      unique(e.id);
      require(e.request['production_category'] == data.account!.mode.name,
          'Kategori evaluasi tidak sesuai akun.');
      require(
          e.contextHash.isNotEmpty &&
              e.request['cattle'] is Map &&
              e.request['feed_items'] is List,
          'Snapshot evaluasi tidak lengkap.');
      final items = e.request['feed_items'] as List;
      require(items.isNotEmpty, 'Bahan evaluasi tidak boleh kosong.');
      final feedIds = <String>{};
      for (final item in items) {
        require(item is Map, 'Bahan evaluasi tidak valid.');
        final feed = item as Map;
        require(
            feed['feed_id'] is String &&
                (feed['feed_id'] as String).isNotEmpty &&
                feedIds.add(feed['feed_id'] as String) &&
                feed['as_fed_kg_day'] is num,
            'Bahan evaluasi tidak valid atau duplikat.');
        positive((feed['as_fed_kg_day'] as num).toDouble(), 'Jumlah bahan');
      }
      require(fingerprint(e.contextSnapshot) == e.contextHash,
          'Snapshot konteks evaluasi berubah atau rusak.');
      final responseMode = e.response['production_category'];
      require(responseMode == null || responseMode == data.account!.mode.name,
          'Kategori respons tidak sesuai evaluasi.');
    }
  }
}
