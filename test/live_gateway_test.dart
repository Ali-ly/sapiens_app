// Explicit opt-in real browser requests, including Gateway CORS/preflight. Synthetic data only.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sapiens_app/api/contracts.dart';
import 'package:sapiens_app/api/gateway_client.dart';
import 'package:sapiens_app/application/farm_controller.dart';
import 'package:sapiens_app/application/providers.dart';
import 'package:sapiens_app/data/backup_codec.dart';
import 'package:sapiens_app/data/farm_repository.dart';
import 'package:sapiens_app/domain/condition.dart';
import 'package:sapiens_app/domain/records.dart';
import 'package:sapiens_app/domain/value.dart';

import 'helpers/harness.dart' show MemoryStorage;

void main() {
  const enabled = bool.fromEnvironment('LIVE_GATEWAY');
  for (final mode in FarmMode.values) {
    test(
        'LIVE ${mode.name}: account → cattle → catalog → v2 evaluation → durable snapshot',
        () async {
      final gateway = GatewayClient();
      final storage = MemoryStorage();
      final container = ProviderContainer(overrides: [
        repositoryProvider.overrideWithValue(FarmRepository(storage)),
        gatewayProvider.overrideWithValue(gateway)
      ]);
      addTearDown(container.dispose);
      addTearDown(gateway.close);
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
      expect(result.response['production_category'], mode.name);
    }, skip: !enabled, timeout: const Timeout(Duration(minutes: 3)));
  }
}
