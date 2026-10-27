import 'platform_storage_stub.dart'
    if (dart.library.io) 'platform_storage_native.dart'
    if (dart.library.html) 'platform_storage_web.dart' as platform;

abstract interface class SnapshotStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class DeviceSnapshotStorage implements SnapshotStorage {
  @override
  Future<String?> read() => platform.read();
  @override
  Future<void> write(String value) => platform.write(value);
}
