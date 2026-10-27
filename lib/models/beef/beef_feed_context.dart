import '../cattle.dart';
import '../domain_json.dart';

class BeefFeedContext {
  const BeefFeedContext(
      {required this.revision, required this.purpose, required this.phase});
  final int revision;
  final BeefPurpose purpose;
  final BeefPhase phase;
  static String? limitation(Cattle c, String target) {
    if (!c.isActive) {
      return 'Profil nonaktif tidak dapat menerima rencana baru.';
    }
    if (c.productionCategory == ProductionCategory.dairy) {
      return 'API saat ini belum mendukung ransum Dairy/laktasi.';
    }
    if (c.productionCategory != ProductionCategory.beef) return null;
    final b = c.modules.beef;
    if (b?.purpose == null || b?.phase == null) {
      return 'Tentukan tujuan dan fase Beef di profil terlebih dahulu.';
    }
    if (b!.purpose != BeefPurpose.fattening) {
      return 'Ransum Pembibitan belum didukung API; catatan reproduksi tetap dapat digunakan.';
    }
    if ({BeefPhase.calf, BeefPhase.weaned}.contains(b.phase)) {
      return 'Ransum anak/lepas sapih belum didukung API.';
    }
    final expected =
        b.phase == BeefPhase.growing ? 'pertumbuhan' : 'penggemukan';
    if (target != expected) {
      return 'Target API untuk fase ini harus $expected. Fase tidak dikirim ke backend.';
    }
    final checks = <String, BeefRecord>{
      for (final r in b.records)
        if (r.kind == BeefRecordKind.pregnancy && r.relatedId != null)
          r.relatedId!: r
    };
    if (checks.values.any((p) =>
        p.pregnancy == PregnancyResult.positive &&
        !b.records.any(
            (r) => r.kind == BeefRecordKind.calving && r.relatedId == p.id))) {
      return 'Ada pemeriksaan manual terkini yang positif; ransum generik tidak mendukung konteks tersebut.';
    }
    return null;
  }

  bool matches(Cattle c) =>
      c.productionCategory == ProductionCategory.beef &&
      c.modules.beef?.records.length == revision &&
      c.modules.beef?.purpose == purpose &&
      c.modules.beef?.phase == phase;
  Map<String, dynamic> toJson() => {
        'version': 1,
        'category': 'beef',
        'mode': 'genericWeightOnly',
        'revision': revision,
        'purpose': purpose.name,
        'phase': phase.name
      };
  factory BeefFeedContext.fromJson(Map<String, dynamic> j) {
    DomainJson.fields(
        j, {'version', 'category', 'mode', 'revision', 'purpose', 'phase'});
    DomainJson.version(j);
    if (j['category'] != 'beef' ||
        j['mode'] != 'genericWeightOnly' ||
        j['revision'] is! int ||
        (j['revision'] as int) < 1) {
      throw const FormatException('Konteks pakan Beef tidak valid.');
    }
    return BeefFeedContext(
        revision: j['revision'] as int,
        purpose: BeefPurpose.values.byName(j['purpose'] as String),
        phase: BeefPhase.values.byName(j['phase'] as String));
  }
}
