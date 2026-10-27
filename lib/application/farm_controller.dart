import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/contracts.dart';
import '../data/backup_codec.dart';
import '../domain/cattle.dart';
import '../domain/condition.dart';
import '../domain/milk_metrics.dart';
import '../domain/records.dart';
import '../domain/value.dart';
import 'nutrition_context.dart';
import 'providers.dart';
export '../domain/cattle.dart';

class WeightInput {
  WeightInput(
      {required this.kg,
      this.source = WeightSource.manual,
      List<UploadPhoto> photos = const [],
      Json quality = const {}})
      : photos = List.unmodifiable(photos),
        quality = frozenJson(quality);
  factory WeightInput.estimate(WeightEstimate e) => WeightInput(
      kg: e.kg,
      source: WeightSource.photoEstimation,
      photos: e.accepted,
      quality: e.raw);
  final double kg;
  final WeightSource source;
  final List<UploadPhoto> photos;
  final Json quality;
}

class FarmController extends AsyncNotifier<FarmData> {
  bool _disposed = false;
  DateTime get now => ref.read(clockProvider)().toUtc();
  String id() => ref.read(idProvider)();
  @override
  Future<FarmData> build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return ref.watch(repositoryProvider).load();
  }

  Future<FarmData> _change(FarmData Function(FarmData) update) async {
    final next = await ref.read(repositoryProvider).transact(update);
    if (!_disposed &&
        (state.valueOrNull == null ||
            next.revision >= state.valueOrNull!.revision)) {
      state = AsyncData(next);
    }
    return next;
  }

  Cattle _editable(FarmData data, String cattleId) {
    final c = data.find(cattleId);
    require(c != null && c.active,
        'Sapi aktif tidak ditemukan. Kembali ke daftar ternak.');
    return c!;
  }

  Future<void> start(FarmMode mode) async {
    await _change((old) {
      require(old.account == null && old.cattle.isEmpty,
          'Akun sudah memiliki mode. Gunakan Ganti Jenis Peternakan.');
      final time = now;
      return FarmData(
          account: FarmAccount(
              id: id(), mode: mode, createdAt: time, updatedAt: time),
          revision: old.revision + 1);
    });
  }

  Future<void> changeMode(FarmMode mode,
      {required FarmData expected, required bool confirmed}) async {
    await _change((old) {
      require(identical(old, expected),
          'Data berubah. Periksa jumlah sapi lagi sebelum mengganti mode.');
      require(confirmed, 'Penghapusan data harus dikonfirmasi.');
      final a = old.account!;
      if (a.mode == mode) return old;
      return FarmData(
          account: FarmAccount(
              id: a.id,
              mode: mode,
              owner: a.owner,
              farmName: a.farmName,
              createdAt: a.createdAt,
              updatedAt: now),
          revision: old.revision + 1);
    });
  }

  Future<void> account(String owner, String name) async {
    await _change((old) {
      final a = old.account!;
      return FarmData(
          account: FarmAccount(
              id: a.id,
              mode: a.mode,
              createdAt: a.createdAt,
              updatedAt: now,
              owner: owner.trim(),
              farmName: name.trim()),
          revision: old.revision + 1,
          cattle: old.cattle);
    });
  }

  ({WeightRecord weight, List<CattlePhoto> photos}) _measurement(
      WeightInput input, DateTime time) {
    positive(input.kg, 'Bobot');
    require(
        input.source != WeightSource.photoEstimation || input.photos.isNotEmpty,
        'Estimasi foto harus memiliki foto valid.');
    final weightId = id();
    final photos = input.photos
        .map((p) => CattlePhoto(
            id: id(),
            name: p.name,
            bytes: p.bytes,
            addedAt: time,
            weightId: weightId))
        .toList();
    return (
      weight: WeightRecord(
          id: weightId,
          kg: input.kg,
          source: input.source,
          measuredAt: time,
          photoIds: photos.map((p) => p.id).toList(),
          quality: input.quality),
      photos: photos
    );
  }

  Future<String> createCattle(
      {required String name,
      required String userId,
      required Sex sex,
      required int ageMonths,
      required Condition condition,
      required WeightInput initialWeight,
      required String expectedAccountId,
      required FarmMode expectedMode}) async {
    late String cattleId;
    await _change((old) {
      require(
          old.account?.id == expectedAccountId &&
              old.account?.mode == expectedMode,
          'Mode peternakan berubah. Buka ulang Tambah Sapi.');
      final time = now, measurement = _measurement(initialWeight, now);
      cattleId = id();
      final c = Cattle(
          id: cattleId,
          name: name.trim(),
          userId: userId.trim(),
          sex: sex,
          ageMonths: ageMonths,
          createdAt: time,
          updatedAt: time,
          weights: [measurement.weight],
          photos: measurement.photos,
          conditions: [
            ConditionRecord(
                id: id(), value: condition, effectiveAt: time, createdAt: time)
          ]);
      return FarmData(
          account: old.account,
          revision: old.revision + 1,
          cattle: [...old.cattle, c]);
    });
    return cattleId;
  }

  Future<void> identity(String cattleId,
      {required String name,
      required String userId,
      required Sex sex,
      required int ageMonths,
      DairyStage? correctedStage,
      Pregnancy? correctedPregnancy}) async {
    await _change((old) {
      final c = _editable(old, cattleId), time = now;
      Condition? amended;
      if (sex != c.sex) {
        final prior = c.condition;
        if (prior is DairyCondition) {
          require(sex != Sex.female || correctedStage != null,
              'Pilih fase fisiologis untuk koreksi menjadi betina perah.');
          amended =
              DairyCondition(stage: sex == Sex.female ? correctedStage : null);
        }
        if (prior is BeefCondition) {
          amended = BeefCondition(
              purpose: prior.purpose,
              phase: prior.phase,
              targetAdg: prior.targetAdg,
              pregnancy:
                  sex == Sex.female && prior.purpose == BeefPurpose.breeding
                      ? correctedPregnancy
                      : null);
        }
      }
      return old.replace(c.copy(
          name: name.trim(),
          userId: userId.trim(),
          sex: sex,
          ageMonths: ageMonths,
          updatedAt: time,
          conditions: amended == null
              ? null
              : [
                  ...c.conditions,
                  ConditionRecord(
                      id: id(),
                      value: amended,
                      effectiveAt: time,
                      createdAt: time)
                ]));
    });
  }

  Future<void> condition(String cattleId, Condition value,
      {required String expectedCondition}) async {
    await _change((old) {
      final c = _editable(old, cattleId), time = now;
      require(c.conditions.last.id == expectedCondition,
          'Kondisi berubah. Buka ulang formulir Perawatan.');
      return old.replace(c.copy(updatedAt: time, conditions: [
        ...c.conditions,
        ConditionRecord(
            id: id(), value: value, effectiveAt: time, createdAt: time)
      ]));
    });
  }

  Future<void> addWeight(String cattleId, WeightInput input,
      {required String expectedWeight}) async {
    await _change((old) {
      final c = _editable(old, cattleId), time = now;
      require(c.latestWeight.id == expectedWeight,
          'Ada pengukuran lebih baru. Tinjau Bobot sebelum menyimpan hasil ini.');
      final m = _measurement(input, time);
      return old.replace(c.copy(
          updatedAt: time,
          weights: [...c.weights, m.weight],
          photos: [...c.photos, ...m.photos]));
    });
  }

  Future<void> addPhotos(String cattleId, List<UploadPhoto> photos) async {
    await _change((old) {
      final c = _editable(old, cattleId), time = now;
      require(photos.isNotEmpty, 'Pilih foto terlebih dahulu.');
      return old.replace(c.copy(updatedAt: time, photos: [
        ...c.photos,
        ...photos.map((p) =>
            CattlePhoto(id: id(), name: p.name, bytes: p.bytes, addedAt: time))
      ]));
    });
  }

  Future<void> archive(String cattleId, bool archived) async {
    await _change((old) {
      final c = old.find(cattleId);
      require(c != null, 'Sapi tidak ditemukan.');
      return old.replace(c!.copy(
          updatedAt: now,
          archivedAt: archived ? now : null,
          restore: !archived));
    });
  }

  Future<void> milk(String cattleId,
      {required String date,
      required MilkMode mode,
      required MilkUnit unit,
      double? total,
      double? am,
      double? pm,
      String? expectedCurrentId}) async {
    await _change((old) {
      final c = _editable(old, cattleId);
      require(old.account!.mode == FarmMode.dairy && c.sex == Sex.female,
          'Produksi susu hanya untuk betina perah.');
      require(calendar(date).compareTo(calendar(day(now.toLocal()))) <= 0,
          'Tanggal susu tidak boleh di masa depan.');
      final current = c.milk.where((m) => m.date == date).lastOrNull;
      require(current?.id == expectedCurrentId,
          'Catatan hari ini sudah berubah. Buka ulang untuk koreksi.');
      require(
          current != null ||
              (c.condition as DairyCondition).stage?.lactating == true,
          'Fase belum laktasi. Histori lama tetap tersedia; catat fase laktasi yang sebenarnya sebelum menambah produksi.');
      final record = MilkRecord(
          id: id(),
          date: date,
          mode: mode,
          unit: unit,
          total: total,
          am: am,
          pm: pm,
          correctionOf: current?.id,
          createdAt: now);
      return old.replace(c.copy(updatedAt: now, milk: [...c.milk, record]));
    });
  }

  Future<void> dairyEvent(String cattleId,
      {required DairyEventKind kind,
      required String date,
      String note = '',
      Pregnancy? pregnancy,
      int? parity,
      String? until,
      String? relatedId,
      required int expectedEventCount}) async {
    await _change((old) {
      final c = _editable(old, cattleId);
      require(old.account!.mode == FarmMode.dairy && c.sex == Sex.female,
          'Reproduksi perah hanya untuk betina.');
      require(c.events.length == expectedEventCount,
          'Riwayat berubah. Buka ulang formulir.');
      require(calendar(date).compareTo(calendar(day(now.toLocal()))) <= 0,
          'Tanggal kejadian tidak boleh di masa depan.');
      final metrics = MilkMetrics(c, now);
      final number = kind == DairyEventKind.calving &&
              metrics.calving != null &&
              metrics.parity != null
          ? metrics.parity! + 1
          : parity;
      final record = DairyEvent(
          id: id(),
          kind: kind,
          date: date,
          createdAt: now,
          note: note.trim(),
          pregnancy: pregnancy,
          parity: number,
          until: until,
          relatedId: relatedId);
      final context = c.condition as DairyCondition;
      final conditions = kind == DairyEventKind.calving
          ? [
              ...c.conditions,
              ConditionRecord(
                  id: id(),
                  value: DairyCondition.fromJson(
                      {...context.toJson(), 'parity': number}),
                  effectiveAt: now,
                  createdAt: now)
            ]
          : c.conditions;
      return old.replace(c.copy(
          updatedAt: now,
          events: [...c.events, record],
          conditions: conditions));
    });
  }

  Future<NutritionEvaluation> evaluate(String cattleId,
      List<FeedAmount> amounts, List<FeedIngredient> catalog) async {
    final initial = state.requireValue;
    final c = _editable(initial, cattleId);
    final context = NutritionContext(initial.account!.mode, c, now);
    final request = context.request(amounts, catalog);
    final hash = context.hash;
    final response = await ref.read(gatewayProvider).nutrition(request);
    final e = NutritionEvaluation(
        id: id(),
        createdAt: now,
        contextHash: hash,
        contextSnapshot: context.snapshot,
        request: request,
        response: response,
        feedNames: {
          for (final f in catalog)
            if (amounts.any((a) => a.feedId == f.id)) f.id: f.name
        });
    // Results are saved atomically only if their original context still applies.
    await _change((old) {
      final latest = _editable(old, cattleId);
      require(
          old.account!.id == initial.account!.id &&
              old.account!.mode == initial.account!.mode &&
              NutritionContext(old.account!.mode, latest, now).hash == hash,
          'Data sapi berubah selama evaluasi. Hasil tidak disimpan; evaluasi ulang dengan data terbaru.');
      return old.replace(
          latest.copy(updatedAt: now, evaluations: [...latest.evaluations, e]));
    });
    return e;
  }

  String export() => BackupCodec.encode(state.requireValue);
  Future<void> restore(String raw, {FarmData? expected}) async {
    final next =
        await ref.read(repositoryProvider).restore(raw, expected: expected);
    if (!_disposed) state = AsyncData(next);
  }
}
