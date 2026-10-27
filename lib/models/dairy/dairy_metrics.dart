import '../cattle.dart';
import 'dairy_calendar.dart';

class MilkDay {
  const MilkDay(this.record, this.withheld);
  final MilkRecord record;
  final bool withheld;
  double get liters => record.recordedLiters;
  double get withheldLiters => withheld ? liters : 0;
  double get outsideHoldLiters => withheld ? 0 : liters;
}

/// Read-only observations. Missing days/sessions are never synthesized as zero.
class DairyMetrics {
  DairyMetrics(Cattle c, DateTime now, {String? calendarDay, String? cycleId}) {
    asOfDay = calendarDay ?? DairyCalendar.day(now.toLocal());
    DairyCalendar.parse(asOfDay);
    final dairy = c.modules.dairy ?? const DairyExtension();
    final records = dairy.records
        .where((r) =>
            !r.recordedAt.isAfter(now) &&
            (r.kind == DairyRecordKind.withholding ||
                r.day.compareTo(asOfDay) <= 0))
        .toList();
    final holds = <String, DairyRecord>{};
    for (final r
        in records.where((r) => r.kind == DairyRecordKind.withholding)) {
      holds.remove(r.supersedesId);
      holds[r.id] = r;
    }
    activeHolds = List.unmodifiable(holds.values);
    bool held(String day) => holds.values.any(
        (r) => r.day.compareTo(day) <= 0 && day.compareTo(r.safeUseDay!) < 0);
    heldToday = held(asOfDay);
    final byDay = <String, MilkRecord>{
      for (final m in dairy.milk)
        if (!m.recordedAt.isAfter(now) && m.day.compareTo(asOfDay) <= 0)
          m.day: m
    };
    milk = List.unmodifiable((byDay.values.toList()
          ..sort((a, b) => a.day.compareTo(b.day)))
        .map((m) => MilkDay(m, held(m.day))));
    completeDays = List.unmodifiable(milk.where((m) => m.record.complete));
    if (completeDays.isNotEmpty) {
      average = completeDays.fold<double>(
          0.0, (v, m) => v + m.liters / completeDays.length);
    }
    if (completeDays.length >= 2) {
      final a = completeDays[completeDays.length - 2], b = completeDays.last;
      trendDelta = b.liters - a.liters;
      trendGapDays = DairyCalendar.days(a.record.day, b.record.day);
    }
    cycles = List.unmodifiable(
        records.where((r) => r.kind == DairyRecordKind.calving));
    cycle = cycleId == null
        ? cycles.lastOrNull
        : cycles.where((r) => r.id == cycleId).firstOrNull;
    if (cycle == null) {
      curve = const [];
      return;
    }
    final index = cycles.indexOf(cycle!);
    final next = index + 1 < cycles.length ? cycles[index + 1] : null;
    if (next == null) dim = DairyCalendar.days(cycle!.day, asOfDay);
    if (index > 0) {
      calvingInterval = DairyCalendar.days(cycles[index - 1].day, cycle!.day);
    }
    curve = List.unmodifiable(completeDays.where((m) =>
        m.record.day.compareTo(cycle!.day) >= 0 &&
        (next == null || m.record.day.compareTo(next.day) < 0)));
    if (curve.isNotEmpty) {
      peak = curve.reduce((a, b) => a.liters >= b.liters ? a : b);
    }
    final startPosition = records.indexOf(cycle!);
    final nextPosition = next == null ? null : records.indexOf(next);
    // Dates determine membership; persisted order disambiguates records on the
    // calving date without inventing a time of day.
    final services = records
        .where((r) =>
            r.kind == DairyRecordKind.service &&
            (r.day.compareTo(cycle!.day) > 0 ||
                r.day == cycle!.day && records.indexOf(r) > startPosition) &&
            (next == null ||
                r.day.compareTo(next.day) < 0 ||
                r.day == next.day && records.indexOf(r) < nextPosition!))
        .toList();
    final checks = <String, DairyRecord>{
      for (final r in records)
        if (r.kind == DairyRecordKind.pregnancy && r.relatedId != null)
          r.relatedId!: r
    };
    final successful = services
        .where((s) =>
            checks[s.id]?.pregnancy == PregnancyResult.positive &&
            checks[s.id]?.confirmedConception == true)
        .toList();
    if (successful.length == 1) {
      final service = successful.single;
      daysOpen = DairyCalendar.days(cycle!.day, service.day);
      servicesPerConception = services
          .where((s) =>
              s.day.compareTo(service.day) < 0 ||
              s.day == service.day &&
                  records.indexOf(s) <= records.indexOf(service))
          .length;
    }
  }
  late final String asOfDay;
  late final List<MilkDay> milk, completeDays, curve;
  late final List<DairyRecord> cycles, activeHolds;
  DairyRecord? cycle;
  MilkDay? peak;
  bool heldToday = false;
  double? average, trendDelta;
  int? trendGapDays, dim, daysOpen, servicesPerConception, calvingInterval;
  List<MilkDay> completeWindow(int days) {
    if (!{7, 30}.contains(days)) {
      throw ArgumentError('Window harus 7 atau 30 hari.');
    }
    return List.unmodifiable(completeDays
        .where((m) => DairyCalendar.days(m.record.day, asOfDay) < days));
  }

  double? averageWindow(int days) {
    final rows = completeWindow(days);
    return rows.isEmpty
        ? null
        : rows.fold<double>(0.0, (v, m) => v + m.liters / rows.length);
  }

  MilkDay? get today => milk.where((m) => m.record.day == asOfDay).firstOrNull;
  MilkDay? get latest => milk.lastOrNull;
}

class DairyHerdMilk {
  DairyHerdMilk(Iterable<Cattle> cattle, DateTime now, {String? calendarDay}) {
    for (final c in cattle.where((c) =>
        c.isActive &&
        c.productionCategory == ProductionCategory.dairy &&
        c.gender == 'Betina')) {
      totalCows++;
      final day = DairyMetrics(c, now, calendarDay: calendarDay).today;
      if (day == null) {
        missingCows++;
        continue;
      }
      recordedCows++;
      if (day.record.complete) {
        completeCows++;
      } else {
        partialCows++;
      }
      liters += day.liters;
      withheld += day.withheldLiters;
      outsideHold += day.outsideHoldLiters;
    }
  }
  int totalCows = 0,
      recordedCows = 0,
      completeCows = 0,
      partialCows = 0,
      missingCows = 0;
  double liters = 0, withheld = 0, outsideHold = 0;
}
