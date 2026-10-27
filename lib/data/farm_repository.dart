import '../domain/cattle.dart';
import '../domain/validation.dart';
import '../domain/value.dart';
import 'backup_codec.dart';
import 'snapshot_storage.dart';

/// One durable account transaction at a time. Failed writes never publish data.
class FarmRepository {
  FarmRepository(this.storage);
  final SnapshotStorage storage;
  FarmData? _current;
  Future<void> _tail = Future.value();
  Future<FarmData> load() async {
    await _tail;
    if (_current != null) return _current!;
    final raw = await storage.read();
    return _current = raw == null ? FarmData() : BackupCodec.decode(raw);
  }

  Future<FarmData> transact(FarmData Function(FarmData) transform) {
    final op = _tail.then((_) async {
      final old = _current;
      require(old != null,
          'Penyimpanan belum siap. Muat ulang atau pulihkan cadangan.');
      final next = transform(old!);
      validateFarm(next);
      await storage.write(BackupCodec.encode(next));
      _current = next;
      return next;
    });
    _tail = op.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return op;
  }

  Future<FarmData> restore(String raw, {FarmData? expected}) {
    final imported = BackupCodec.decode(raw);
    final op = _tail.then((_) async {
      require(expected == null || identical(expected, _current),
          'Data berubah saat konfirmasi terbuka. Periksa cadangan lagi.');
      final next = FarmData(
          account: imported.account,
          cattle: imported.cattle,
          revision: (_current?.revision ?? imported.revision) + 1);
      await storage.write(BackupCodec.encode(next));
      _current = next;
      return next;
    });
    _tail = op.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return op;
  }
}
