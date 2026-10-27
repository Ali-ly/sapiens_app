import 'dart:convert';

import 'package:crypto/crypto.dart';

typedef Json = Map<String, dynamic>;
Json object(Object? value) {
  if (value is! Map) throw const FormatException('Struktur data tidak valid.');
  return Map<String, dynamic>.from(value);
}

List<T> records<T>(Object? value, T Function(Json) parse) {
  if (value is! List) {
    throw const FormatException('Daftar catatan tidak valid.');
  }
  return List.unmodifiable(value.map((v) => parse(object(v))));
}

DateTime instant(Object? value) => DateTime.parse(value as String);
String day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
DateTime calendar(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Tanggal harus YYYY-MM-DD.');
  }
  final d = DateTime.parse('${value}T00:00:00Z');
  if (day(d) != value) throw const FormatException('Tanggal tidak valid.');
  return d;
}

int calendarDays(String a, String b) =>
    calendar(b).difference(calendar(a)).inDays;
void require(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

void positive(double? value, String label, {bool zero = false}) {
  require(value != null && value.isFinite && (zero ? value >= 0 : value > 0),
      '$label harus ${zero ? 'nol atau lebih' : 'lebih dari nol'}.');
}

Object? canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((e) => e.toString()).toList()..sort();
    return {for (final k in keys) k: canonical(value[k])};
  }
  if (value is List) return value.map(canonical).toList();
  return value;
}

String fingerprint(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();
Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
        value.map((k, v) => MapEntry(k.toString(), _freeze(v))));
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

Json frozenJson(Json value) => _freeze(jsonDecode(jsonEncode(value))) as Json;
void known(Json value, Set<String> keys) => require(
    value.keys.every(keys.contains),
    'Data memuat field yang belum didukung. Gunakan versi aplikasi yang sesuai.');

enum FarmMode { beef, dairy }

extension FarmModeText on FarmMode {
  String get label => this == FarmMode.beef ? 'Sapi Potong' : 'Sapi Perah';
  String get farmer =>
      this == FarmMode.beef ? 'Peternak Sapi Potong' : 'Peternak Sapi Perah';
}

enum Sex { male, female }

extension SexText on Sex {
  String get label => this == Sex.male ? 'Jantan' : 'Betina';
}

enum BeefPurpose { fattening, breeding }

extension PurposeText on BeefPurpose {
  String get label =>
      this == BeefPurpose.fattening ? 'Penggemukan' : 'Pembibitan';
}

enum FatteningPhase { early, late }

extension PhaseText on FatteningPhase {
  String get label =>
      this == FatteningPhase.early ? 'Penggemukan Awal' : 'Penggemukan Akhir';
}

enum Pregnancy { pregnant, notPregnant, uncertain }

extension PregnancyText on Pregnancy {
  String get label => switch (this) {
        Pregnancy.pregnant => 'Bunting',
        Pregnancy.notPregnant => 'Tidak bunting',
        Pregnancy.uncertain => 'Belum pasti'
      };
}

enum DairyStage {
  preweaningCalf,
  growingHeifer,
  pregnantHeifer,
  fresh,
  earlyLactation,
  midLactation,
  lateLactation,
  dryFarOff,
  closeUp
}

extension DairyStageText on DairyStage {
  String get label => const [
        'Pedet belum sapih',
        'Dara tumbuh',
        'Dara bunting',
        'Baru beranak / Fresh',
        'Laktasi awal',
        'Laktasi tengah',
        'Laktasi akhir',
        'Kering kandang',
        'Menjelang beranak / Close-Up'
      ][index];
  String get wire => const [
        'preweaning_calf',
        'growing_heifer',
        'pregnant_heifer',
        'fresh',
        'early_lactation',
        'mid_lactation',
        'late_lactation',
        'dry_far_off',
        'close_up'
      ][index];
  bool get lactating => {
        DairyStage.fresh,
        DairyStage.earlyLactation,
        DairyStage.midLactation,
        DairyStage.lateLactation
      }.contains(this);
}
