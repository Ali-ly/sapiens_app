import 'persisted_time.dart';

class WeightRecord {
  const WeightRecord(
      {required this.weightKg,
      required this.date,
      this.source = 'unknown',
      this.id,
      this.dateText});

  final String? id;
  final String? dateText;
  TimestampBasis get timestampBasis => dateText == null
      ? TimestampBasis.explicitOffset
      : PersistedTime.basis(dateText!);
  final double weightKg;
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'weight': weightKg,
        'date': PersistedTime.encode(date, dateText),
        'source': source
      };
  final DateTime date;
  final String source;
  String get sourceLabel =>
      {
        'ai': 'Estimasi foto AI',
        'manual': 'Timbangan manual',
        'demo': 'Data contoh',
        'unknown': 'Catatan bobot'
      }[source] ??
      'Catatan bobot';
}
