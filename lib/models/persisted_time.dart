enum TimestampBasis { explicitOffset, legacyLocalUnknown }

/// Preserve source literals, including offset-less dates whose absolute timezone
/// was never recorded. The DateTime view retains the existing local parsing rule.
class PersistedTime {
  static DateTime parse(String literal) {
    final date = RegExp(
            r'^(\d{4})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2}):(\d{2})(?:[.,]\d+)?(?:[zZ]|[+-]\d{2}(?::?\d{2})?)?)?$')
        .firstMatch(literal);
    if (date == null) {
      throw const FormatException('Timestamp tidak sesuai format ISO.');
    }
    final year = int.parse(date[1]!),
        month = int.parse(date[2]!),
        day = int.parse(date[3]!);
    final calendar = DateTime.utc(year, month, day);
    if (calendar.year != year ||
        calendar.month != month ||
        calendar.day != day ||
        date[4] != null &&
            (int.parse(date[4]!) > 23 ||
                int.parse(date[5]!) > 59 ||
                int.parse(date[6]!) > 59)) {
      throw const FormatException('Timestamp kalender tidak valid.');
    }
    final offset = date[4] == null
        ? null
        : RegExp(r'[+-](\d{2})(?::?(\d{2}))?$').firstMatch(literal);
    if (offset != null &&
        (int.parse(offset[1]!) > 23 ||
            offset[2] != null && int.parse(offset[2]!) > 59)) {
      throw const FormatException('Offset timestamp tidak valid.');
    }
    return DateTime.parse(literal);
  }

  static TimestampBasis basis(String literal) =>
      RegExp(r'[Tt ]').hasMatch(literal) &&
              RegExp(r'([zZ]|[+-]\d{2}(?::?\d{2})?)$').hasMatch(literal)
          ? TimestampBasis.explicitOffset
          : TimestampBasis.legacyLocalUnknown;
  static String encode(DateTime value, [String? original]) {
    if (original == null) return value.toUtc().toIso8601String();
    if (!parse(original).isAtSameMomentAs(value)) {
      throw const FormatException('Timestamp asli tidak sesuai nilai waktu.');
    }
    return original;
  }

  static String? optional(DateTime? value, [String? original]) =>
      value == null ? null : encode(value, original);
}
