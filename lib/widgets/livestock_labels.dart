import '../models/cattle.dart';
import '../models/persisted_time.dart';
import 'farm_feedback.dart';

String productionLabel(ProductionCategory? value) => switch (value) {
      ProductionCategory.beef => 'Beef',
      ProductionCategory.dairy => 'Dairy',
      null => 'Belum diklasifikasi',
    };
String farmProductionLabel(FarmProductionSystems? value) => switch (value) {
      FarmProductionSystems.beef => 'Beef',
      FarmProductionSystems.dairy => 'Dairy',
      FarmProductionSystems.both => 'Both',
      null => 'Belum dipilih',
    };
String lifeStageLabel(LifeStage? value) => switch (value) {
      LifeStage.calf => 'Anak sapi',
      LifeStage.youngstock => 'Ternak muda',
      LifeStage.adult => 'Dewasa',
      null => 'Belum dicatat',
    };
String healthKindLabel(HealthKind value) => switch (value) {
      HealthKind.observation => 'Observasi',
      HealthKind.treatment => 'Tindakan/perawatan',
      HealthKind.vaccination => 'Vaksinasi',
      HealthKind.deworming => 'Pemberian obat cacing',
      HealthKind.preventiveCare => 'Perawatan pencegahan',
    };
String ageEvidenceLabel(Cattle c) =>
    switch (c.core.identity.ageEvidence.certainty) {
      AgeCertainty.exact =>
        'Tanggal lahir pasti: ${c.core.identity.ageEvidence.birthDate}',
      AgeCertainty.estimated => c.core.identity.ageEvidence.birthDate == null
          ? 'Estimasi umur: ${c.ageMonths} bulan'
          : 'Perkiraan tanggal lahir: ${c.core.identity.ageEvidence.birthDate}',
      AgeCertainty.unknown => 'Umur belum diketahui',
    };
String timestampLabel(DateTime value, [String? original]) {
  final local = value.toLocal();
  final date =
      '${dateLabel(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return original != null &&
          PersistedTime.basis(original) == TimestampBasis.legacyLocalUnknown
      ? '$date · zona waktu asal tidak tercatat'
      : date;
}

String inputTime(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
DateTime? parseInputTime(String text) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$').hasMatch(text.trim())) {
    return null;
  }
  try {
    return PersistedTime.parse('${text.trim().replaceFirst(' ', 'T')}:00');
  } on FormatException {
    return null;
  }
}
