import '../models/cattle.dart';

/// Explicit opt-in demo data; never used as a fallback for failed API calls.
List<Cattle> createSampleCattle(DateTime now) {
  const names = [
    'B001 - Budi',
    'B002 - Sari',
    'B003 - Jaya',
    'B004 - Miko',
    'B005 - Bima'
  ];
  const weights = [348.0, 312.0, 285.0, 401.0, 267.0];
  const lastCheckDays = [1, 3, 5, 10, 7];
  return List.generate(
    names.length,
    (index) => Cattle(
      id: 'demo-$index',
      nameOrId: names[index],
      gender: index == 1 ? 'Betina' : 'Jantan',
      ageMonths: 18 + index * 2,
      estimatedWeight: weights[index],
      notes: 'Data contoh untuk mencoba aplikasi.',
      history: List.generate(
        4,
        (check) => WeightRecord(
          weightKg: weights[index] - (3 - check) * 9,
          source: 'demo',
          date: now.subtract(
            Duration(
              days: lastCheckDays[index] + (3 - check) * 14,
            ),
          ),
        ),
      ),
    ),
  );
}
