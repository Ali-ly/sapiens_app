import '../persisted_time.dart';

/// Explicit civil dates, not guessed instants from legacy timestamps. UTC is
/// used only as an ordinal calendar for subtraction (including DST changes).
class DairyCalendar {
  static DateTime parse(String day) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw const FormatException('Tanggal harus YYYY-MM-DD.');
    }
    PersistedTime.parse(day);
    final p = day.split('-').map(int.parse).toList();
    return DateTime.utc(p[0], p[1], p[2]);
  }

  static String day(DateTime civil) =>
      '${civil.year.toString().padLeft(4, '0')}-${civil.month.toString().padLeft(2, '0')}-${civil.day.toString().padLeft(2, '0')}';
  static int days(String from, String to) =>
      parse(to).difference(parse(from)).inDays;
  static void captured(DateTime at, String on) {
    parse(on);
    if (days(day(at.toUtc()), on).abs() > 1) {
      throw const FormatException(
          'Tanggal pencatatan tidak cocok dengan waktu pencatatan.');
    }
  }
}
