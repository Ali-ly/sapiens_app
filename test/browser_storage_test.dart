import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapiens_app/data/backup_codec.dart';
import 'package:sapiens_app/data/farm_repository.dart';
import 'package:sapiens_app/data/snapshot_storage.dart';
import 'package:sapiens_app/domain/value.dart';
import 'helpers/harness.dart';

void main() {
  test('IndexedDB persists a validated full account across repository reloads',
      () async {
    final h = Harness();
    addTearDown(h.dispose);
    await h.start(FarmMode.dairy);
    await h.lactating();
    final raw = h.controller.export(), device = DeviceSnapshotStorage();
    await device.write(raw);
    final loaded = await FarmRepository(device).load();
    expect(loaded.toJson(), h.data.toJson());
    expect(BackupCodec.decode((await device.read())!).account!.mode,
        FarmMode.dairy);
  }, skip: !kIsWeb);
}
