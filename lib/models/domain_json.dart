/// Fail closed for versioned domain records without coupling models to storage.
class DomainJson {
  static void fields(Map<String, dynamic> value, Set<String> allowed) {
    if (value.keys.any((k) => !allowed.contains(k))) {
      throw const FormatException('Catatan memuat field yang belum didukung.');
    }
  }

  static void version(Map<String, dynamic> value, {int expected = 1}) {
    if (value['version'] is! int || value['version'] != expected) {
      throw const FormatException('Versi catatan belum didukung.');
    }
  }
}
