import 'dart:convert';
import '../domain/cattle.dart';
import '../domain/validation.dart';
import '../domain/value.dart';

class BackupCodec {
  static const version = 1;
  static String encode(FarmData data) {
    validateFarm(data);
    final payload = data.toJson();
    return jsonEncode({
      'application': 'sapiens-rebuild',
      'schemaVersion': version,
      'minimumReaderVersion': version,
      'checksum': fingerprint(payload),
      'payload': payload
    });
  }

  static FarmData decode(String raw) {
    try {
      final j = object(jsonDecode(raw));
      known(j, {
        'application',
        'schemaVersion',
        'minimumReaderVersion',
        'checksum',
        'payload'
      });
      require(j['application'] == 'sapiens-rebuild',
          'Cadangan ini bukan format SAPIENS baru. Data aplikasi lama tidak dimigrasikan otomatis.');
      require(
          j['schemaVersion'] == version && j['minimumReaderVersion'] == version,
          'Versi cadangan belum didukung. Data lokal tidak akan diganti.');
      final payload = object(j['payload']);
      require(j['checksum'] == fingerprint(payload),
          'Isi cadangan berubah atau rusak.');
      final data = FarmData.fromJson(payload);
      validateFarm(data);
      return data;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'Cadangan tidak valid atau memerlukan aplikasi yang lebih baru.');
    }
  }
}
