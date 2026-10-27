import 'domain_json.dart';
import 'feed_plan.dart';
import 'persisted_time.dart';

enum StockMovement { received, used, correction }

/// Signed corrections are explicit adjustments, never a rewritten balance.
class StockEntry {
  const StockEntry(
      {required this.id,
      required this.feed,
      required this.kind,
      required this.kg,
      required this.recordedAt,
      required this.note});
  final String id, feed, note;
  final StockMovement kind;
  final double kg;
  final DateTime recordedAt;
  double get delta => kind == StockMovement.used ? -kg : kg;
  Map<String, dynamic> toJson() => {
        'id': id,
        'feed': feed,
        'kind': kind.name,
        'kg': kg,
        'unit': 'kgAsFed',
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'note': note
      };
  factory StockEntry.fromJson(Map<String, dynamic> j) {
    DomainJson.fields(
        j, {'id', 'feed', 'kind', 'kg', 'unit', 'recordedAt', 'note'});
    if (j['unit'] != 'kgAsFed' ||
        PersistedTime.basis(j['recordedAt'] as String) !=
            TimestampBasis.explicitOffset) {
      throw const FormatException('Satuan/waktu stok tidak didukung.');
    }
    return StockEntry(
        id: j['id'] as String,
        feed: j['feed'] as String,
        kind: StockMovement.values.byName(j['kind'] as String),
        kg: (j['kg'] as num).toDouble(),
        recordedAt: PersistedTime.parse(j['recordedAt'] as String),
        note: j['note'] as String);
  }
  static Map<String, double> balances(Iterable<StockEntry> entries) {
    final result = {for (final f in feedLabels.keys) f: 0.0};
    for (final e in entries) {
      result.update(e.feed, (v) => v + e.delta, ifAbsent: () => e.delta);
    }
    return Map.unmodifiable(result);
  }
}
