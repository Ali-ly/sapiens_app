// Explicit opt-in live verification. Uses only synthetic cattle and a public photo.
import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sapiens_app/api/contracts.dart';
import 'package:sapiens_app/api/gateway_client.dart';
import 'package:sapiens_app/application/farm_controller.dart';
import 'package:sapiens_app/application/providers.dart';
import 'package:sapiens_app/data/backup_codec.dart';
import 'package:sapiens_app/data/farm_repository.dart';
import 'package:sapiens_app/domain/condition.dart';
import 'package:sapiens_app/domain/records.dart';
import 'package:sapiens_app/domain/value.dart';

import '../test/helpers/harness.dart' show MemoryStorage;

class LiveNetwork extends HttpOverrides {}

void main() {
  const enabled = bool.fromEnvironment('LIVE_GATEWAY');
  final results = <String, Object?>{};
  for (final mode in FarmMode.values) {
    test(
        'LIVE ${mode.name}: account → cattle → catalog → v2 evaluation → durable snapshot',
        () async {
      final client = HttpOverrides.runWithHttpOverrides(
          () => http.Client(), LiveNetwork());
      final gateway = GatewayClient(client: client);
      final storage = MemoryStorage();
      final container = ProviderContainer(overrides: [
        repositoryProvider.overrideWithValue(FarmRepository(storage)),
        gatewayProvider.overrideWithValue(gateway)
      ]);
      addTearDown(container.dispose);
      addTearDown(client.close);
      await container.read(farmProvider.future);
      final app = container.read(farmProvider.notifier), now = DateTime.now();
      expect((await gateway.health())['status'], 'healthy');
      await app.start(mode);
      final account = container.read(farmProvider).requireValue.account!;
      final id = await app.createCattle(
          name: 'LIVE TEST — synthetic ${mode.name}',
          userId: '',
          sex: Sex.female,
          ageMonths: 24,
          condition: mode == FarmMode.beef
              ? const BeefCondition(
                  purpose: BeefPurpose.fattening,
                  phase: FatteningPhase.early,
                  targetAdg: .5)
              : const DairyCondition(
                  stage: DairyStage.earlyLactation,
                  milkFat: 3.8,
                  milkProtein: 3.2,
                  bcs: 3),
          initialWeight: WeightInput(kg: mode == FarmMode.beef ? 300 : 500),
          expectedAccountId: account.id,
          expectedMode: mode);
      if (mode == FarmMode.dairy) {
        await app.dairyEvent(id,
            kind: DairyEventKind.calving,
            date: day(now.subtract(const Duration(days: 30))),
            parity: 1,
            expectedEventCount: 0);
        await app.milk(id,
            date: day(now),
            mode: MilkMode.totalDaily,
            unit: MilkUnit.kg,
            total: 15);
      }
      final feeds = await gateway.feeds(mode);
      expect(feeds.every((f) => f.validFor.contains(mode)), isTrue);
      final ingredient = feeds.firstWhere((f) => f.id == 'rumput_gajah');
      final result =
          await app.evaluate(id, [FeedAmount(ingredient.id, 25)], feeds);
      final restored = BackupCodec.decode(storage.raw!);
      expect(restored.find(id)!.evaluations.single.toJson(), result.toJson());
      results[mode.name] = {
        'status': result.response['status'],
        'catalog_count': feeds.length,
        'snapshot_saved': true,
        'schema': 1
      };
    }, skip: !enabled, timeout: const Timeout(Duration(minutes: 3)));
  }
  test('LIVE /v2/weight uses public cow photo with multipart files', () async {
    const path = String.fromEnvironment('LIVE_PHOTO');
    expect(path, isNotEmpty);
    final client =
        HttpOverrides.runWithHttpOverrides(() => http.Client(), LiveNetwork());
    final gateway = GatewayClient(client: client);
    addTearDown(client.close);
    final result = await gateway.weight([
      UploadPhoto(
          name: 'public-e2e-cow.jpg', bytes: await File(path).readAsBytes())
    ]);
    expect(result.kg, greaterThan(0));
    expect(result.accepted, hasLength(1));
    results['weight'] = {
      'kg': result.kg,
      'accepted': result.accepted.length,
      'rejected': result.rejected.length,
      'endpoint': '/v2/weight'
    };
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 3)));
  tearDownAll(() async {
    if (enabled) {
      const output = String.fromEnvironment('LIVE_REPORT',
          defaultValue: '/tmp/sapiens-rebuild-live-client.json');
      await File(output)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    }
  });
}
