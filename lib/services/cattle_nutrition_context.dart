import '../data/json_value.dart';
import '../models/cattle.dart';
import '../models/dairy/dairy_metrics.dart';
import '../models/feed_api_v2.dart';

/// Project recorded Twin facts into the v2 contract; never infer nutrition goals.
class CattleNutritionContext {
  /// ADG is an explicit evaluation input, not a fact inferred from the Twin.
  static bool matchesTwin(
      NutritionCattleContext context, Cattle cattle, DateTime now) {
    final recorded = fromTwin(cattle, now).toJson();
    final input = context.toJson();
    if (context.productionCategory != cattle.productionCategory) return false;
    if (recorded['purpose'] == 'penggemukan') {
      final adg = input.remove('target_adg_kg_day');
      if (adg != null && (adg is! num || !adg.isFinite || adg <= 0)) {
        return false;
      }
    }
    return sameJson(input, recorded);
  }

  static NutritionCattleContext fromTwin(Cattle cattle, DateTime now) {
    if (!cattle.isActive) {
      throw const FormatException('Sapi nonaktif tidak dapat dievaluasi.');
    }
    final weight = cattle.estimatedWeight;
    if (weight == null || !weight.isFinite || weight <= 0) {
      throw const FormatException('Catat bobot sapi terlebih dahulu.');
    }
    switch (cattle.productionCategory) {
      case null:
        throw const FormatException(
            'Klasifikasikan kategori produksi sapi di profil terlebih dahulu.');
      case ProductionCategory.beef:
        final purpose = cattle.modules.beef?.purpose;
        if (purpose == null) {
          throw const FormatException(
              'Catat tujuan Beef di profil terlebih dahulu.');
        }
        return NutritionCattleContext.beef(
          bodyWeightKg: weight,
          purpose:
              purpose == BeefPurpose.fattening ? 'penggemukan' : 'pembibitan',
        );
      case ProductionCategory.dairy:
        final stage = cattle.modules.dairy?.phase;
        if (stage == null) {
          throw const FormatException(
              'Catat fase Dairy di profil terlebih dahulu.');
        }
        final metrics = DairyMetrics(cattle, now);
        // parity is an explicit user baseline / validated increment on a real
        // calving, unlike cycles.length (only the number of recorded cycles).
        final parity = metrics.cycle?.parity;
        final parityGroup = switch (parity) {
          1 => 'primiparous',
          final int n when n >= 2 => 'multiparous',
          _ => null,
        };
        if ({DairyPhase.heifer, DairyPhase.firstPregnancy}.contains(stage) &&
            (cattle.gender != 'Betina' || metrics.cycles.isNotEmpty)) {
          throw const FormatException(
              'Konteks dara tidak sesuai jenis kelamin atau histori calving. Periksa fase Dairy di profil.');
        }
        return NutritionCattleContext.dairy(
          bodyWeightKg: weight,
          dairyStage: _backendDairyStage(stage),
          dim: metrics.dim,
          parityGroup: parityGroup,
        );
    }
  }

  /// Explicit backend contract, confirmed by the user. No age/day thresholds
  /// or automatic transition to another Twin phase is involved.
  static String _backendDairyStage(DairyPhase stage) => switch (stage) {
        DairyPhase.preWeaning => 'preweaning_calf',
        DairyPhase.heifer => 'growing_heifer',
        DairyPhase.firstPregnancy => 'pregnant_heifer',
        DairyPhase.fresh => 'fresh',
        DairyPhase.early => 'early_lactation',
        DairyPhase.mid => 'mid_lactation',
        DairyPhase.late => 'late_lactation',
        DairyPhase.dry => 'dry_far_off',
        DairyPhase.closeUp => 'close_up',
        DairyPhase.newborn ||
        DairyPhase.weaned ||
        DairyPhase.breedingReady ||
        DairyPhase.calving =>
          throw FormatException(
              'Fase ${dairyPhaseLabels[stage]} belum memiliki padanan nutrisi backend yang pasti. Periksa fase di profil; evaluasi tidak dikirim.'),
      };

  static const dairyLimitations =
      'Susu dicatat dalam liter, sehingga berat susu dalam kg belum tersedia. '
      'Kelompok paritas hanya dikirim dari nomor laktasi/paritas yang tercatat jelas. '
      'Lemak dan protein tidak ditebak; layanan dapat menolak data yang belum lengkap.';
}
