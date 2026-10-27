import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sapiens_app/api/contracts.dart';
import 'package:sapiens_app/application/farm_controller.dart';
import 'package:sapiens_app/application/providers.dart';
import 'package:sapiens_app/data/farm_repository.dart';
import 'package:sapiens_app/data/snapshot_storage.dart';
import 'package:sapiens_app/domain/condition.dart';
import 'package:sapiens_app/domain/records.dart';
import 'package:sapiens_app/domain/value.dart';

import 'live_fixtures.dart';

class MemoryStorage implements SnapshotStorage {
  String? raw;
  bool fail = false;
  int writes = 0;
  @override
  Future<String?> read() async => raw;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Penyimpanan penuh');
    writes++;
    raw = value;
  }
}

class FakeGateway implements Gateway {
  Json? lastRequest;
  int nutritionCalls = 0, catalogCalls = 0, weightCalls = 0;
  Future<Json> Function(Json)? respond;
  Future<WeightEstimate> Function(List<UploadPhoto>)? estimate;
  @override
  Future<Json> health() async => {'status': 'healthy'};
  @override
  Future<List<FeedIngredient>> feeds(FarmMode mode) async {
    catalogCalls++;
    final j = mode == FarmMode.beef ? beefCatalog() : dairyCatalog();
    return (j['feeds'] as List)
        .map((e) => FeedIngredient.fromJson(object(e)))
        .where((e) => e.validFor.contains(mode))
        .toList();
  }

  @override
  Future<Json> nutrition(Json request) async {
    nutritionCalls++;
    lastRequest = object(jsonDecode(jsonEncode(request)));
    if (respond != null) return respond!(request);
    return request['production_category'] == 'beef'
        ? beefResponse()
        : dairyResponse();
  }

  @override
  Future<WeightEstimate> weight(List<UploadPhoto> photos) async {
    weightCalls++;
    if (estimate != null) return estimate!(photos);
    return WeightEstimate.parse(
        {...weightResponse(), 'num_valid_images': photos.length}, photos);
  }
}

class Harness {
  Harness({List<Override> overrides = const []}) {
    repository = FarmRepository(storage);
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repository),
      gatewayProvider.overrideWithValue(gateway),
      clockProvider.overrideWithValue(() => now),
      ...overrides,
      idProvider.overrideWithValue(() => 'id-${counter++}')
    ]);
  }
  final storage = MemoryStorage(), gateway = FakeGateway();
  late final FarmRepository repository;
  late final ProviderContainer container;
  DateTime now = DateTime.utc(2026, 10, 27, 12);
  int counter = 0;
  FarmController get controller => container.read(farmProvider.notifier);
  FarmData get data => container.read(farmProvider).requireValue;
  Future<void> start(FarmMode mode) async {
    await container.read(farmProvider.future);
    await controller.start(mode);
  }

  Future<Cattle> add(
      {String name = 'Sapi uji',
      Sex? sex,
      Condition? condition,
      WeightInput? weight}) async {
    final a = data.account!;
    final actualSex = sex ?? (a.mode == FarmMode.beef ? Sex.male : Sex.female);
    final id = await controller.createCattle(
        name: name,
        userId: '',
        sex: actualSex,
        ageMonths: 24,
        condition: condition ??
            (a.mode == FarmMode.beef
                ? const BeefCondition(
                    purpose: BeefPurpose.fattening,
                    phase: FatteningPhase.early,
                    targetAdg: .5)
                : actualSex == Sex.male
                    ? const DairyCondition()
                    : const DairyCondition(stage: DairyStage.fresh)),
        initialWeight: weight ?? WeightInput(kg: 300),
        expectedAccountId: a.id,
        expectedMode: a.mode);
    return data.find(id)!;
  }

  Future<Cattle> lactating() async {
    final c = await add(
        condition: const DairyCondition(
            stage: DairyStage.earlyLactation, milkFat: 3.8, milkProtein: 3.2));
    await controller.dairyEvent(c.id,
        kind: DairyEventKind.calving,
        date: '2026-10-01',
        parity: 1,
        expectedEventCount: 0);
    await controller.milk(c.id,
        date: '2026-10-27',
        mode: MilkMode.totalDaily,
        unit: MilkUnit.kg,
        total: 15);
    return data.find(c.id)!;
  }

  Future<NutritionEvaluation> evaluate(String id) async => controller.evaluate(
      id,
      [const FeedAmount('rumput_gajah', 25)],
      await gateway.feeds(data.account!.mode));
  void dispose() => container.dispose();
}
