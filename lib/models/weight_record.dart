class WeightRecord {
  const WeightRecord(
      {required this.weightKg, required this.date, this.source = 'unknown'});

  final double weightKg;
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
