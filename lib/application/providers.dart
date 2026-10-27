import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../api/contracts.dart';
import '../api/gateway_client.dart';
import '../data/farm_repository.dart';
import '../data/snapshot_storage.dart';
import '../domain/value.dart';
import 'farm_controller.dart';

final gatewayProvider = Provider<Gateway>((ref) {
  final gateway = GatewayClient();
  ref.onDispose(gateway.close);
  return gateway;
});
final repositoryProvider =
    Provider<FarmRepository>((ref) => FarmRepository(DeviceSnapshotStorage()));
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final idProvider = Provider<String Function()>((ref) => const Uuid().v4);
final farmProvider =
    AsyncNotifierProvider<FarmController, FarmData>(FarmController.new);
final feedCatalogProvider = FutureProvider.autoDispose
    .family<List<FeedIngredient>, FarmMode>(
        (ref, mode) => ref.watch(gatewayProvider).feeds(mode));
final gatewayHealthProvider = FutureProvider.autoDispose<Json>(
    (ref) => ref.watch(gatewayProvider).health());
