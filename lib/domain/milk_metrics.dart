import 'cattle.dart';
import 'condition.dart';
import 'records.dart';
import 'value.dart';

class MilkMetrics {
  MilkMetrics(this.cattle, DateTime now) : today = day(now.toLocal()) {
    final byDay = <String, MilkRecord>{};
    for (final m in cattle.milk) {
      if (m.date.compareTo(today) <= 0 && !m.createdAt.isAfter(now)) {
        byDay[m.date] = m;
      }
    }
    days = List.unmodifiable(
        byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date)));
    final births = cattle.events
        .where((e) =>
            e.kind == DairyEventKind.calving &&
            e.date.compareTo(today) <= 0 &&
            !e.createdAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    calving = births.lastOrNull;
    dim = calving == null ? null : calendarDays(calving!.date, today);
    final condition = cattle.condition;
    parity = condition is DairyCondition ? condition.parity : null;
    holds = List.unmodifiable(cattle.events.where((e) =>
        e.kind == DairyEventKind.withholding &&
        e.date.compareTo(today) <= 0 &&
        e.until!.compareTo(today) >= 0 &&
        !e.createdAt.isAfter(now)));
    curve = List.unmodifiable(days.where((m) =>
        m.complete && calving != null && m.date.compareTo(calving!.date) >= 0));
  }
  final Cattle cattle;
  final String today;
  late final List<MilkRecord> days, curve;
  late final List<DairyEvent> holds;
  late final DairyEvent? calving;
  late final int? dim, parity;
  DairyEvent? get latestPregnancyCheck {
    final checks = cattle.events
        .where((e) =>
            e.kind == DairyEventKind.pregnancyCheck &&
            e.date.compareTo(today) <= 0 &&
            (calving == null || e.date.compareTo(calving!.date) >= 0))
        .toList()
      ..sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date != 0 ? date : a.createdAt.compareTo(b.createdAt);
      });
    return checks.lastOrNull;
  }

  MilkRecord? get latest => days.lastOrNull;
  List<MilkRecord> completeFor(MilkUnit unit, {int? horizon}) => days
      .where((m) =>
          m.complete &&
          m.unit == unit &&
          (horizon == null || calendarDays(m.date, today) < horizon))
      .toList();
  double? average(MilkUnit unit, int horizon) {
    final rows = completeFor(unit, horizon: horizon);
    return rows.isEmpty
        ? null
        : rows.fold<double>(0, (v, m) => v + m.recordedAmount) / rows.length;
  }

  MilkRecord? peak(MilkUnit unit) {
    final rows = curve.where((m) => m.unit == unit);
    return rows.isEmpty
        ? null
        : rows.reduce((a, b) => a.recordedAmount >= b.recordedAmount ? a : b);
  }

  double? trend(MilkUnit unit) {
    final rows = completeFor(unit);
    return rows.length < 2
        ? null
        : rows.last.recordedAmount - rows[rows.length - 2].recordedAmount;
  }
}
