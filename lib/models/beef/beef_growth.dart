import '../cattle.dart';
import '../cattle_rules.dart';
import '../persisted_time.dart';

enum HarvestState { notReady, nearTarget, evaluate }

const harvestLabels = {
  HarvestState.notReady: 'Belum siap',
  HarvestState.nearTarget: 'Mendekati target',
  HarvestState.evaluate: 'Siap dievaluasi'
};

/// Interval uses the last two recorded weights as-is. Invalid intervals are not
/// silently replaced by an older pair or fabricated timezone.
class BeefGrowth {
  BeefGrowth(Cattle c, DateTime now) {
    final h = c.history;
    if (h.isEmpty) {
      issue = 'Belum ada bobot.';
      return;
    }
    if (h.any((r) => !CattleRules.isValidWeight(r.weightKg))) {
      issue = 'Histori memuat bobot tidak valid.';
      return;
    }
    final last = h.last;
    if (h.any((r) => r.date.isAfter(now))) {
      issue = 'Histori memuat bobot masa depan.';
      return;
    }
    if (h.any((r) =>
        r.dateText != null &&
        PersistedTime.basis(r.dateText!) ==
            TimestampBasis.legacyLocalUnknown)) {
      issue = 'Zona waktu bobot lama belum diketahui; ADG tidak dihitung.';
      return;
    }
    currentKg = last.weightKg;
    final target = c.modules.beef?.latest(BeefRecordKind.target);
    targetKg = target?.targetKg;
    nearKg = target?.nearKg;
    if (targetKg != null) {
      remainingKg =
          (targetKg! - currentKg!).clamp(0, double.infinity).toDouble();
      progress = (currentKg! / targetKg!).clamp(0, 1).toDouble();
      harvest = currentKg! >= targetKg!
          ? HarvestState.evaluate
          : nearKg != null && currentKg! >= nearKg!
              ? HarvestState.nearTarget
              : HarvestState.notReady;
    }
    if (h.length < 2) {
      issue = 'Perlu dua catatan bobot untuk ADG.';
      return;
    }
    // Reject any non-increasing timestamps, including earlier duplicate entries.
    for (var i = 1; i < h.length; i++) {
      if (!h[i].date.isAfter(h[i - 1].date)) {
        issue = 'Waktu bobot duplikat/tidak berurutan; ADG tidak dihitung.';
        return;
      }
    }
    final first = h[h.length - 2];
    intervalDays = last.date.difference(first.date).inMicroseconds /
        Duration.microsecondsPerDay;
    deltaKg = last.weightKg - first.weightKg;
    adg = deltaKg! / intervalDays!;
    if (adg! > 0 && remainingKg != null && remainingKg! > 0) {
      final days = remainingKg! / adg!;
      // DateTime representability is a technical bound, not a growth threshold.
      if (days.isFinite && days < 1000000) projectedDays = days;
    }
  }
  double? currentKg,
      targetKg,
      nearKg,
      remainingKg,
      progress,
      deltaKg,
      intervalDays,
      adg,
      projectedDays;
  String? issue;
  HarvestState harvest = HarvestState.notReady;
  String get trend => adg == null
      ? 'Belum tersedia'
      : adg! > 0
          ? 'Naik'
          : adg! < 0
              ? 'Turun'
              : 'Tetap';
}
