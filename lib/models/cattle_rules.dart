import 'cattle.dart';

/// Validation shared by persistence and mutations, independent of the UI.
class CattleRules {
  static const minimumWeight = 1.0;
  static const maximumWeight = 2000.0;
  static const maximumAgeMonths = 360;
  static const genders = {'Jantan', 'Betina'};
  static const reminderIntervals = {3, 7, 14, 30};

  static bool isValidWeight(double weight) =>
      weight.isFinite && weight >= minimumWeight && weight <= maximumWeight;

  static void validate(Cattle animal, {bool requireId = true}) {
    if (requireId && animal.id.trim().isEmpty ||
        animal.nameOrId.trim().isEmpty ||
        animal.nameOrId.trim().length > 60 ||
        animal.notes.length > 500 ||
        animal.ageMonths < 1 ||
        animal.ageMonths > maximumAgeMonths ||
        !genders.contains(animal.gender)) {
      throw const FormatException('Identitas sapi tidak valid.');
    }
    final weight = animal.estimatedWeight;
    if (weight != null && !isValidWeight(weight)) {
      throw const FormatException('Bobot harus berada antara 1 dan 2.000 kg.');
    }
    DateTime? previous;
    for (final record in animal.history) {
      if (!isValidWeight(record.weightKg) ||
          previous != null && record.date.isBefore(previous)) {
        throw const FormatException(
          'Riwayat bobot tidak valid atau tidak berurutan.',
        );
      }
      previous = record.date;
    }
    if (animal.history.isNotEmpty && animal.history.last.weightKg != weight) {
      throw const FormatException(
        'Bobot terbaru tidak sesuai dengan catatan terakhir.',
      );
    }
    final spread = animal.predictionSpread;
    if (spread != null && (!spread.isFinite || spread < 0) ||
        animal.validImages < 0 ||
        animal.rejectedImages < 0) {
      throw const FormatException('Data estimasi bobot tidak valid.');
    }
  }
}
