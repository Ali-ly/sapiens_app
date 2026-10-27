import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/cattle_codec.dart';
import '../data/farm_backup_codec.dart';
import '../data/farm_identity.dart';
import '../data/json_value.dart';
import '../data/sample_cattle.dart';
import '../data/snapshot_upgrade.dart';
import '../data/twin_codec.dart';
import '../models/beef/beef_feed_context.dart';
import '../models/beef/beef_feed_demand.dart';
import '../models/cattle.dart';
import '../models/cattle_rules.dart';
import '../models/dairy/dairy_calendar.dart';
import '../models/dairy/dairy_metrics.dart';
import '../models/farm_command_center.dart';
import '../models/farm_snapshot.dart';
import '../models/farm_status.dart';
import '../models/feed_api_v2.dart';
import '../models/feed_plan.dart';
import '../models/feed_plan_rules.dart';
import '../models/feed_stock.dart';
import '../models/group_feed_plan.dart';
import '../models/group_record.dart';
import '../models/group_rules.dart';
import '../models/livestock_group.dart';
import '../models/selected_image.dart';
import '../models/twin_rules.dart';
import '../services/cattle_nutrition_context.dart';
import 'local_storage.dart' as storage;

/// Coordinates local state and serialized writes. Views cannot mutate snapshots.
class FarmStore extends ChangeNotifier {
  FarmStore(
      {Future<String?> Function()? read,
      Future<void> Function(String)? write,
      DateTime Function()? now})
      : _read = read ?? storage.readData,
        _write = write ?? storage.writeData,
        _now = now ?? DateTime.now;

  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final DateTime Function() _now;
  FarmSnapshot _snapshot = FarmSnapshot();
  Future<void> _writeTail = Future.value();
  Future<void>? _loading;
  bool _ready = false, _disposed = false;
  String? _error;
  int _idCounter = 0;
  final _reservedIds = <String>{};

  /// Operational lists exclude exited Twins; byId/allCattle retain their history.
  List<Cattle> get cattle =>
      List.unmodifiable(allCattle.where((c) => c.isActive));
  List<Cattle> get allCattle => _snapshot.cattle;
  List<Cattle> get inactiveCattle =>
      List.unmodifiable(allCattle.where((c) => !c.isActive));
  FarmProductionSystems? get productionSystems => _snapshot.productionSystems;
  List<Cattle> get activeDairy => List.unmodifiable(
      cattle.where((c) => c.productionCategory == ProductionCategory.dairy));
  DairyHerdMilk get dairyMilk => DairyHerdMilk(cattle, _now());
  List<StockEntry> get feedStock => _snapshot.feedStock;
  BeefFeedDemand beefDemand([int days = 1]) =>
      BeefFeedDemand(_snapshot, _now(), days: days);
  List<Cattle> get activeBeef => List.unmodifiable(
      cattle.where((c) => c.productionCategory == ProductionCategory.beef));
  List<FeedPlan> get feedPlans => _snapshot.feedPlans;
  List<LivestockGroup> get groups => _snapshot.groups;
  List<LivestockGroup> get activeGroups =>
      List.unmodifiable(groups.where((g) => !g.archived));
  List<GroupFeedPlan> get groupFeedPlans => _snapshot.groupFeedPlans;
  int get groupHeadCount => activeGroups.fold(0, (sum, g) => sum + g.headCount);
  LivestockGroup? groupById(String id) {
    for (final group in groups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  GroupFeedPlan? latestGroupPlan(String id) {
    GroupFeedPlan? latest;
    for (final plan in groupFeedPlans.where((p) => p.groupId == id)) {
      if (latest == null || !plan.createdAt.isBefore(latest.createdAt)) {
        latest = plan;
      }
    }
    return latest;
  }

  bool groupPlanReady(LivestockGroup group) =>
      latestGroupPlan(group.id)?.matches(group) == true;
  Map<String, double> get groupDailyFeedTotals {
    final result = <String, double>{};
    for (final group in activeGroups.where(groupPlanReady)) {
      for (final portion in latestGroupPlan(group.id)!.groupPortions) {
        result.update(portion.key, (kg) => kg + portion.asFedKg,
            ifAbsent: () => portion.asFedKg);
      }
    }
    return Map.unmodifiable(result);
  }

  String _newId(String kind) {
    final existing = {
      ..._reservedIds,
      ...feedStock.map((e) => e.id),
      ...allCattle.expand((c) => [
            ...?c.modules.dairy?.records.map((r) => r.id),
            ...?c.modules.dairy?.milk.map((r) => r.id)
          ]),
      ...allCattle
          .expand((c) => c.modules.beef?.records ?? <BeefRecord>[])
          .map((r) => r.id),
      ...allCattle.map((c) => c.id),
      ...allCattle.expand((c) => c.images).map((i) => i.id).whereType<String>(),
      ..._snapshot.legacyMemberships.map((m) => m.id),
      ...feedPlans.map((p) => p.id),
      ...allCattle
          .expand((c) => c.history)
          .map((r) => r.id)
          .whereType<String>(),
      ...allCattle.expand((c) => c.core.lifecycle.statuses).map((r) => r.id),
      ...allCattle.expand((c) => c.core.lifecycle.stages).map((r) => r.id),
      ...allCattle.expand((c) => c.core.health).map((r) => r.id),
      ...allCattle.expand((c) => c.core.photos.history).map((r) => r.id),
      ...allCattle.expand((c) => c.core.timeline).map((r) => r.id),
      ...groups.map((g) => g.id),
      ...groups.expand((g) => g.history).map((r) => r.id),
      ...groupFeedPlans.map((p) => p.id)
    };
    String id;
    do {
      id = '$kind-${_now().microsecondsSinceEpoch}-${_idCounter++}';
    } while (existing.contains(id));
    _reservedIds.add(id);
    return id;
  }

  Future<LivestockGroup> createGroup(String name,
      {required int headCount,
      double? averageWeightKg,
      String target = 'pemeliharaan',
      String notes = ''}) async {
    late LivestockGroup created;
    await _commit(() {
      final now = _now().toUtc();
      created = LivestockGroup(id: _newId('group'), createdAt: now, history: [
        GroupRecord(
            id: _newId('record'),
            recordedAt: now,
            name: name.trim(),
            headCount: headCount,
            averageWeightKg: averageWeightKg,
            target: target,
            notes: notes.trim())
      ]);
      return _snapshot.copyWith(groups: [...groups, created]);
    });
    return created;
  }

  Future<void> updateGroup(String id,
          {required String name,
          required int headCount,
          required double? averageWeightKg,
          required String target,
          required String notes}) =>
      _commit(() {
        final group = groupById(id);
        if (group == null || group.archived) {
          throw StateError('Kelompok aktif tidak ditemukan.');
        }
        final record = group.current.copyWith(
            id: _newId('record'),
            recordedAt: _now().toUtc(),
            name: name.trim(),
            headCount: headCount,
            averageWeightKg: averageWeightKg,
            clearWeight: averageWeightKg == null,
            target: target,
            notes: notes.trim(),
            source: 'manual');
        return _snapshot.copyWith(
            groups: groups
                .map((g) => g.id == id ? group.append(record) : g)
                .toList());
      });
  Future<void> archiveGroup(String id) => _setGroupArchive(id, true);
  Future<void> restoreGroup(String id) => _setGroupArchive(id, false);
  Future<void> _setGroupArchive(String id, bool archived) => _commit(() {
        final group = groupById(id);
        if (group == null) {
          throw StateError('Kelompok tidak ditemukan.');
        }
        if (group.archived == archived) {
          return _snapshot;
        }
        final now = _now().toUtc();
        final record = group.current.copyWith(
            id: _newId('record'),
            recordedAt: now,
            archivedAt: archived ? now : null,
            clearArchive: !archived,
            source: archived ? 'archive' : 'restore');
        return _snapshot.copyWith(
            groups: groups
                .map((g) => g.id == id ? group.append(record) : g)
                .toList());
      });
  Future<void> saveGroupPlan(GroupFeedPlan plan) => _commit(() {
        for (final existing in groupFeedPlans.where((p) => p.id == plan.id)) {
          if (sameJson(existing.toJson(), plan.toJson())) return _snapshot;
          throw StateError(
              'ID rencana kelompok sudah digunakan. Buat rencana baru.');
        }
        final group = groupById(plan.groupId);
        if (group == null || !plan.matches(group)) {
          throw StateError(
              'Data kelompok berubah. Hitung ulang pakan dengan data terkini.');
        }
        GroupRules.validatePlan(plan, group);
        return _snapshot.copyWith(groupFeedPlans: [...groupFeedPlans, plan]);
      });

  DateTime get currentTime => _now();
  String get settingsRevision =>
      jsonEncode([farmId, farmer, farm, reminderDays, productionSystems?.name]);
  String get farmId => _snapshot.farmId;
  String get farmer => _snapshot.farmer;
  String get farm => _snapshot.farm;
  int get reminderDays => _snapshot.reminderDays;
  bool get demo => _snapshot.hasExamples;
  bool get ready => _ready;
  String? get error => _error;

  Future<void> load() {
    if (_loading != null) {
      return _loading!;
    }
    final operation = _writeTail.then((_) => _loadSnapshot());
    _writeTail = operation.catchError((Object _) {});
    _loading = operation;
    return operation.whenComplete(() => _loading = null);
  }

  Future<void> _loadSnapshot() async {
    _error = null;
    try {
      final raw = await _read();
      final result = raw == null ? null : FarmBackupCodec.read(raw);
      final next = result?.snapshot ??
          FarmSnapshot(
              farmId: FarmIdentity.newLocal(),
              farmIdentityOrigin: FarmIdentityOrigin.localRandom);
      // Validate/upgrade and durably write before publishing the migrated state.
      if (raw == null || result?.needsUpgrade == true) {
        await _write(jsonEncode(FarmBackupCodec.encode(next)));
      }
      _snapshot = next;
    } catch (_) {
      _error =
          'Data lokal belum bisa dibaca. Data lama tidak akan ditimpa; muat ulang aplikasi untuk mencoba lagi.';
    }
    _ready = true;
    _notify();
  }

  Cattle? byId(String id) {
    for (final animal in allCattle) {
      if (animal.id == id) {
        return animal;
      }
    }
    return null;
  }

  FeedPlan? latestPlan(String cattleId) =>
      FarmStatus.latestPlan(feedPlans, cattleId);
  bool needsCheck(Cattle animal) =>
      FarmStatus.needsWeightCheck(animal, _now(), reminderDays);
  bool planReady(Cattle animal) =>
      FarmStatus.planReady(animal, latestPlan(animal.id), _now(), reminderDays);
  FarmCommandCenter get commandCenter =>
      FarmCommandCenter.fromSnapshot(_snapshot, _now());
  int get checksThisWeek {
    final now = _now();
    return cattle.fold(
      0,
      (total, animal) =>
          total +
          animal.history
              .where(
                (record) =>
                    !record.date.isAfter(now) &&
                    now.difference(record.date) < const Duration(days: 7),
              )
              .length,
    );
  }

  double get totalWeight => cattle.fold(
        0.0,
        (total, animal) => total + (animal.estimatedWeight ?? 0),
      );
  Map<String, double> get dailyFeedTotals {
    final totals = <String, double>{};
    for (final animal in cattle.where(planReady)) {
      for (final portion in latestPlan(animal.id)!.portions) {
        totals.update(
          portion.key,
          (value) => value + portion.asFedKg,
          ifAbsent: () => portion.asFedKg,
        );
      }
    }
    return Map.unmodifiable(totals);
  }

  /// Builders run at write time, so concurrent mutations use the latest snapshot.
  Future<void> _commit(FarmSnapshot Function() build,
      {bool recovering = false}) {
    final initialized = _ready ? Future<void>.value() : load();
    final operation = _writeTail.then(
      (_) async {
        await initialized;
        if (_error != null && !recovering) {
          throw StateError(_error!);
        }
        final proposed = build();
        if (identical(proposed, _snapshot)) return;
        final next = SnapshotUpgrade.complete(proposed);
        GroupRules.validate(next);
        TwinRules.validate(next);
        await _write(jsonEncode(FarmBackupCodec.encode(next)));
        _snapshot = next;
        _error = null;
        _notify();
      },
    );
    // One failed disk write must not prevent later writes from being attempted.
    _writeTail = operation.catchError((Object _) {});
    return operation;
  }

  FarmSnapshot _withCattle(List<Cattle> animals) =>
      _snapshot.copyWith(cattle: animals);

  void _checkUniqueName(Cattle animal) {
    if (allCattle.any(
      (other) =>
          other.id != animal.id &&
          other.nameOrId.trim().toLowerCase() ==
              animal.nameOrId.trim().toLowerCase(),
    )) {
      throw StateError('Nama / ID sapi sudah digunakan.');
    }
  }

  /// Legacy full-object API. Existing histories may only be appended, never
  /// replaced; structured Twin updates must use the targeted mutation methods.
  Future<Cattle> saveCattle(Cattle value,
      {String? expectedFarmSettingsRevision}) async {
    CattleRules.validate(value, requireId: false);
    late Cattle saved;
    await _commit(() {
      if (expectedFarmSettingsRevision != null &&
          expectedFarmSettingsRevision != settingsRevision) {
        throw StateError(
            'Pengaturan farm berubah. Buka kembali formulir tambah sapi dengan data terkini.');
      }
      saved = value.copyWith(
          id: value.id.isEmpty ? _newId('cattle') : value.id,
          nameOrId: value.nameOrId.trim());
      final current = byId(saved.id);
      if (current != null) {
        _requireActive(current);
        final before = CattleCodec.encode(current),
            after = CattleCodec.encode(saved);
        if (!isJsonPrefix(
                before['history'] as List, after['history'] as List) ||
            !isJsonPrefix(before['images'] as List, after['images'] as List) ||
            !sameJson(TwinCodec.encode(current), TwinCodec.encode(saved))) {
          throw StateError(
              'Data sapi sudah berubah. Muat ulang profil sebelum menyimpan.');
        }
      } else {
        final category =
            saved.productionCategory ?? productionSystems?.singleCategory;
        if (productionSystems == FarmProductionSystems.both &&
            category == null) {
          throw StateError('Pilih kategori Beef atau Dairy untuk sapi baru.');
        }
        saved = saved.copyWith(productionCategory: category);
      }
      _checkUniqueName(saved);
      return _withCattle([...allCattle.where((c) => c.id != saved.id), saved]);
    });
    return byId(saved.id)!;
  }

  void _requireActive(Cattle? c) {
    if (c == null || !c.isActive) {
      throw StateError('Sapi aktif tidak tersedia. Muat ulang daftar sapi.');
    }
  }

  Future<Cattle> updateIdentity(String id,
      {required String name,
      required String gender,
      required int ageMonths,
      required String notes}) async {
    late Cattle updated;
    await _commit(
      () {
        final current = byId(id);
        if (current == null || !current.isActive) {
          throw StateError(
            'Sapi ini sudah tidak tersedia. Kembali ke daftar sapi.',
          );
        }
        updated = current.copyWith(
          nameOrId: name.trim(),
          gender: gender,
          ageMonths: ageMonths,
          notes: notes.trim(),
        );
        CattleRules.validate(updated);
        _checkUniqueName(updated);
        return _withCattle(
          allCattle
              .map((animal) => animal.id == id ? updated : animal)
              .toList(),
        );
      },
    );
    return byId(updated.id)!;
  }

  Future<Cattle> recordWeight(String id,
      {required double weightKg,
      required String source,
      List<SelectedImage> images = const [],
      double? predictionSpread,
      int validImages = 0,
      int rejectedImages = 0,
      int? expectedHistoryLength}) async {
    late Cattle updated;
    await _commit(
      () {
        final current = byId(id);
        if (current == null || !current.isActive) {
          throw StateError(
            'Sapi ini sudah tidak tersedia. Kembali ke daftar sapi.',
          );
        }
        if (expectedHistoryLength != null &&
            current.history.length != expectedHistoryLength) {
          throw StateError(
            'Catatan bobot sudah berubah. Ulangi pengecekan dengan data terbaru.',
          );
        }
        if (source != 'manual' && source != 'ai') {
          throw ArgumentError.value(
            source,
            'source',
            'Sumber bobot tidak dikenali.',
          );
        }
        final now = _now().toUtc();
        final weightId = _newId('weight');
        final newPhotos = _photoRecords(current, images, now, source, weightId);
        updated = current.copyWith(
          core: current.core.copyWith(
            photos: TwinPhotos(
                images: current.images,
                latestCheckImages: current.latestCheckImages,
                history: [...current.core.photos.history, ...newPhotos]),
            timeline: [
              ...current.core.timeline,
              _event(TwinEventKind.weightRecorded, now, recordId: weightId),
              ...newPhotos.map(
                  (r) => _event(TwinEventKind.photosAdded, now, recordId: r.id))
            ],
          ),
          estimatedWeight: weightKg,
          clearPrediction: predictionSpread == null,
          predictionSpread: predictionSpread,
          validImages: validImages,
          rejectedImages: rejectedImages,
          images: [...current.images, ...images],
          latestCheckImages: images,
          history: [
            ...current.history,
            WeightRecord(
                id: weightId, weightKg: weightKg, date: now, source: source)
          ],
        );
        CattleRules.validate(updated);
        return _withCattle(
          allCattle
              .map((animal) => animal.id == id ? updated : animal)
              .toList(),
        );
      },
    );
    return byId(updated.id)!;
  }

  /// Reserves a collision-safe identity but does not write or publish a plan.
  FeedPlan createNutritionPlan(
      {required Cattle cattle,
      required NutritionRequest request,
      required NutritionResponse response}) {
    final plan = FeedPlan.nutrition(
        id: _newId('nutrition-plan'),
        cattle: cattle,
        request: request,
        response: response,
        createdAt: _now());
    FeedPlanRules.validate(plan);
    if (!nutritionPlanMatches(plan)) {
      throw StateError(
          'Data sapi berubah. Evaluasi ulang dengan konteks terbaru.');
    }
    return plan;
  }

  bool nutritionPlanMatches(FeedPlan plan) {
    final animal = byId(plan.cattleId);
    if (!plan.isNutritionEvaluation ||
        animal == null ||
        !animal.isActive ||
        !plan.matches(animal) ||
        plan.createdAt.isAfter(_now())) return false;
    try {
      return CattleNutritionContext.matchesTwin(
          plan.nutritionRequest!.cattle, animal, _now());
    } on FormatException {
      return false;
    }
  }

  Future<void> savePlan(FeedPlan plan) => _commit(
        () {
          for (final existing in feedPlans.where((p) => p.id == plan.id)) {
            if (sameJson(existing.toJson(), plan.toJson())) return _snapshot;
            throw StateError(
                'ID rencana pakan sudah digunakan. Buat rencana baru.');
          }
          FeedPlanRules.validate(plan);
          final animal = byId(plan.cattleId);
          if (animal == null || !animal.isActive || !plan.matches(animal)) {
            throw StateError(
              'Data sapi berubah. Hitung ulang pakan dengan bobot terbaru.',
            );
          }
          if (plan.isNutritionEvaluation) {
            if (!nutritionPlanMatches(plan)) {
              throw StateError(
                  'Konteks sapi berubah. Evaluasi ulang sebelum menyimpan.');
            }
            return _snapshot.copyWith(feedPlans: [...feedPlans, plan]);
          }
          final limitation = BeefFeedContext.limitation(animal, plan.target!);
          if (limitation != null ||
              animal.productionCategory == ProductionCategory.beef &&
                  plan.beefContext?.matches(animal) != true) {
            throw StateError(limitation ??
                'Rencana belum memiliki konteks Beef terkini. Hitung ulang dalam mode terbatas.');
          }
          return _snapshot.copyWith(
            cattle: allCattle,
            feedPlans: [...feedPlans, plan],
          );
        },
      );

  /// Retained API name for callers; removal now records a reversible archive.
  Future<void> remove(String id) => setCattleStatus(id, CattleStatus.archived);

  Cattle _withStatus(Cattle c, CattleStatus status, String note) {
    if (c.status == status) return c;
    final now = _now().toUtc();
    final record = StatusRecord(
        id: _newId('status'),
        recordedAt: now,
        status: status,
        note: note.trim());
    return c.copyWith(
        core: c.core.copyWith(
      lifecycle: TwinLifecycle(
          statuses: [...c.core.lifecycle.statuses, record],
          stages: c.core.lifecycle.stages),
      timeline: [
        ...c.core.timeline,
        _event(TwinEventKind.statusChanged, now, recordId: record.id)
      ],
    ));
  }

  Future<void> setCattleStatus(String id, CattleStatus status,
          {String note = '',
          int? expectedEventCount,
          String? expectedFarmId}) =>
      _commit(() {
        _expectFarm(expectedFarmId);
        final c = byId(id);
        if (c == null) throw StateError('Sapi tidak ditemukan.');
        _expectTimeline(c, expectedEventCount);
        if (c.status == status) return _snapshot;
        final updated = _withStatus(c, status, note);
        return _withCattle(
            allCattle.map((c) => c.id == id ? updated : c).toList());
      });

  Future<void> removeExamples() => _commit(() => _withCattle(allCattle
      .map((c) => c.id.startsWith('demo-')
          ? _withStatus(c, CattleStatus.archived, 'Arsip data contoh')
          : c)
      .toList()));
  Future<void> addExamples() => _commit(() =>
      allCattle.isEmpty ? _withCattle(createSampleCattle(_now())) : _snapshot);

  void _checkProductionSystems(FarmProductionSystems? systems) {
    if (systems == null) return;
    final conflicts = allCattle
        .where((c) =>
            c.productionCategory != null &&
            !systems.allows(c.productionCategory!))
        .length;
    if (conflicts > 0) {
      throw FormatException(
          '$conflicts profil sapi, termasuk nonaktif, memiliki kategori yang tidak cocok. Pilih Both atau sesuaikan kategori sapi terlebih dahulu.');
    }
  }

  void _expectFarm(String? expected) {
    if (expected != null && expected != farmId) {
      throw StateError(
          'Data peternakan telah diganti. Tutup dan buka kembali formulir.');
    }
  }

  void _expectTimeline(Cattle c, int? expected) {
    if (expected != null && c.core.timeline.length != expected) {
      throw StateError(
          'Data ternak berubah. Tutup dan buka kembali formulir agar memakai catatan terkini.');
    }
  }

  /// Opaque revision covers every record, including writes during confirmation.
  Object get productionChangeRevision => _snapshot;

  /// Explicit farm-type reset. Ordinary cattle removal still archives the Twin.
  Future<void> selectFarmProduction(ProductionCategory category,
          {required Object expectedRevision,
          bool confirmPermanentDeletion = false}) =>
      _commit(() {
        if (!identical(expectedRevision, _snapshot)) {
          throw StateError(
              'Data berubah. Periksa kembali jumlah sapi sebelum mengganti jenis peternakan.');
        }
        final next = category == ProductionCategory.beef
            ? FarmProductionSystems.beef
            : FarmProductionSystems.dairy;
        if (productionSystems == next) return _snapshot;
        final hasIndividualData = allCattle.isNotEmpty ||
            feedPlans.isNotEmpty ||
            _snapshot.legacyMemberships.isNotEmpty;
        if (hasIndividualData && !confirmPermanentDeletion) {
          throw StateError(
              'Penghapusan permanen data sapi harus dikonfirmasi.');
        }
        return _snapshot.copyWith(
            productionSystems: next,
            cattle: [],
            feedPlans: [],
            legacyMemberships: []);
      });

  Future<void> configureProductionSystems(FarmProductionSystems systems) =>
      _commit(() {
        _checkProductionSystems(systems);
        return _snapshot.copyWith(productionSystems: systems);
      });

  Future<void> setProductionCategory(String id, ProductionCategory category,
          {required String reason,
          int? expectedEventCount,
          String? expectedFarmSettingsRevision}) =>
      _commit(() {
        final c = byId(id);
        _requireActive(c);
        _expectTimeline(c!, expectedEventCount);
        if (expectedFarmSettingsRevision != null &&
            expectedFarmSettingsRevision != settingsRevision) {
          throw StateError(
              'Pengaturan farm berubah. Buka kembali formulir kategori dengan data terkini.');
        }
        if (c.productionCategory == category) return _snapshot;
        if (reason.trim().isEmpty) {
          throw ArgumentError('Alasan perubahan kategori diperlukan.');
        }
        final updated = c.copyWith(
            productionCategory: category,
            core: c.core.copyWith(timeline: [
              ...c.core.timeline,
              _event(TwinEventKind.productionCategoryChanged, _now().toUtc(),
                  previousCategory: c.productionCategory,
                  productionCategory: category,
                  note: reason.trim())
            ]));
        return _replace(updated);
      });

  Future<void> recordLifeStage(String id, LifeStage stage,
          {String note = '',
          int? expectedEventCount,
          String? expectedFarmId}) =>
      _commit(() {
        _expectFarm(expectedFarmId);
        final c = byId(id);
        _requireActive(c);
        _expectTimeline(c!, expectedEventCount);
        final now = _now().toUtc();
        final record = LifeStageRecord(
            id: _newId('stage'),
            recordedAt: now,
            stage: stage,
            note: note.trim());
        return _replace(c.copyWith(
            core: c.core.copyWith(
                lifecycle: TwinLifecycle(
                    statuses: c.core.lifecycle.statuses,
                    stages: [...c.core.lifecycle.stages, record]),
                timeline: [
              ...c.core.timeline,
              _event(TwinEventKind.lifeStageChanged, now, recordId: record.id)
            ])));
      });

  Future<void> recordHealth(String id,
          {required HealthKind kind,
          required DateTime occurredAt,
          required String note,
          DateTime? nextDueAt,
          String? expectedFarmId}) =>
      _commit(() {
        _expectFarm(expectedFarmId);
        final c = byId(id);
        _requireActive(c);
        final now = _now().toUtc();
        final record = HealthRecord(
            id: _newId('health'),
            recordedAt: now,
            occurredAt: occurredAt.toUtc(),
            kind: kind,
            note: note.trim(),
            nextDueAt: nextDueAt?.toUtc());
        return _replace(c!.copyWith(
            core: c.core.copyWith(health: [
          ...c.core.health,
          record
        ], timeline: [
          ...c.core.timeline,
          _event(TwinEventKind.healthRecorded, now, recordId: record.id)
        ])));
      });

  /// Assign references explicitly. Existing histories are untouched.
  Future<void> updateReferences(String id, TwinReferences references) =>
      _commit(() {
        final c = byId(id);
        _requireActive(c);
        return _replace(
            c!.copyWith(core: c.core.copyWith(references: references)));
      });

  Future<void> addPhotos(String id, List<SelectedImage> images,
          {String source = 'manual'}) =>
      _commit(() {
        final c = byId(id);
        _requireActive(c);
        if (images.isEmpty) return _snapshot;
        final now = _now().toUtc();
        final photos = _photoRecords(c!, images, now, source, null);
        return _replace(c.copyWith(
            core: c.core.copyWith(
          photos: TwinPhotos(
              images: [...c.images, ...images],
              latestCheckImages: c.latestCheckImages,
              history: [...c.core.photos.history, ...photos]),
          timeline: [
            ...c.core.timeline,
            ...photos.map(
                (p) => _event(TwinEventKind.photosAdded, now, recordId: p.id))
          ],
        )));
      });
  List<PhotoRecord> _photoRecords(Cattle c, List<SelectedImage> images,
          DateTime now, String source, String? weightId) =>
      List.generate(
          images.length,
          (i) => PhotoRecord(
              id: _newId('photo'),
              recordedAt: now,
              imageIndex: c.images.length + i,
              source: source,
              weightRecordId: weightId));
  TwinEvent _event(TwinEventKind kind, DateTime now,
          {String? recordId,
          String note = '',
          ProductionCategory? previousCategory,
          ProductionCategory? productionCategory}) =>
      TwinEvent(
          id: _newId('event'),
          recordedAt: now,
          kind: kind,
          recordId: recordId,
          previousCategory: previousCategory,
          productionCategory: productionCategory,
          note: note);
  FarmSnapshot _replace(Cattle updated) => _withCattle(
      allCattle.map((c) => c.id == updated.id ? updated : c).toList());

  Future<void> recordBeef(String id,
          {required BeefRecordKind kind,
          required String note,
          DateTime? occurredAt,
          BeefPurpose? purpose,
          BeefPhase? phase,
          double? targetKg,
          double? nearKg,
          String? sireId,
          String? relatedId,
          String? calfId,
          PregnancyResult? pregnancy,
          int? expectedRevision,
          String? expectedFarmId}) =>
      _commit(() {
        _expectFarm(expectedFarmId);
        final c = byId(id);
        _requireActive(c);
        if (c!.productionCategory != ProductionCategory.beef) {
          throw StateError('Profil harus berkategori Beef.');
        }
        final old = c.modules.beef ?? const BeefExtension();
        if (expectedRevision != null &&
            old.records.length != expectedRevision) {
          throw StateError('Catatan Beef berubah. Buka kembali form.');
        }
        final now = _now().toUtc();
        final record = BeefRecord(
            id: _newId('beef'),
            kind: kind,
            recordedAt: now,
            occurredAt: (occurredAt ?? now).toUtc(),
            note: note.trim(),
            purpose: purpose,
            phase: phase,
            targetKg: targetKg,
            nearKg: nearKg,
            sireId: sireId,
            relatedId: relatedId,
            calfId: calfId,
            pregnancy: pregnancy);
        final updated = c.copyWith(
            modules: TwinModules(
                beef: BeefExtension.withRecords([...old.records, record]),
                dairy: c.modules.dairy));
        var animals = allCattle.map((a) => a.id == id ? updated : a).toList();
        if (kind == BeefRecordKind.calving && calfId != null) {
          final calf = byId(calfId);
          _requireActive(calf);
          final check = old.records.where((r) => r.id == relatedId).firstOrNull;
          final service =
              old.records.where((r) => r.id == check?.relatedId).firstOrNull;
          if (service == null ||
              calf!.core.references.damId != null &&
                  calf.core.references.damId != c.id ||
              calf.core.references.sireId != null &&
                  service.sireId != null &&
                  calf.core.references.sireId != service.sireId) {
            throw StateError(
                'Referensi anak sudah berbeda atau breeding tidak tersedia.');
          }
          final refs = calf.core.references;
          final linked = calf.copyWith(
              core: calf.core.copyWith(
                  references: TwinReferences(
                      damId: c.id,
                      sireId: service.sireId ?? refs.sireId,
                      externalIds: refs.externalIds)));
          animals = animals.map((a) => a.id == calfId ? linked : a).toList();
        }
        return _withCattle(animals);
      });

  Cattle _dairyCattle(String id, int? revision, String? expectedFarmId) {
    _expectFarm(expectedFarmId);
    final c = byId(id);
    _requireActive(c);
    if (c!.productionCategory != ProductionCategory.dairy) {
      throw StateError('Profil harus berkategori Dairy.');
    }
    if (revision != null && (c.modules.dairy?.revision ?? 0) != revision) {
      throw StateError('Catatan Dairy berubah. Buka kembali form.');
    }
    return c;
  }

  Future<void> recordMilk(String id,
          {required String day,
          required MilkMode mode,
          required String note,
          double? total,
          double? am,
          double? pm,
          String qualityNote = '',
          String? supersedesId,
          int? expectedRevision,
          String? expectedFarmId}) =>
      _commit(() {
        final c = _dairyCattle(id, expectedRevision, expectedFarmId),
            d = c.modules.dairy ?? const DairyExtension();
        final now = _now();
        final m = MilkRecord(
            id: _newId('milk'),
            recordedAt: now.toUtc(),
            recordedOn: DairyCalendar.day(now.toLocal()),
            day: day,
            mode: mode,
            note: note.trim(),
            total: total,
            am: am,
            pm: pm,
            qualityNote: qualityNote.trim(),
            supersedesId: supersedesId);
        return _replace(c.copyWith(
            modules: TwinModules(
                beef: c.modules.beef,
                dairy: DairyExtension.withRecords(
                    records: d.records, milk: [...d.milk, m]))));
      });

  Future<void> recordDairy(String id,
          {required DairyRecordKind kind,
          required String day,
          required String note,
          DairyPhase? phase,
          String? sireId,
          String? relatedId,
          String? calfId,
          PregnancyResult? pregnancy,
          bool confirmedConception = false,
          int? parity,
          String? safeUseDay,
          String? supersedesId,
          String? healthRecordId,
          int? expectedRevision,
          String? expectedFarmId}) =>
      _commit(() {
        final c = _dairyCattle(id, expectedRevision, expectedFarmId),
            d = c.modules.dairy ?? const DairyExtension();
        final now = _now();
        final previous = d.calvings.lastOrNull;
        if (kind == DairyRecordKind.calving &&
            parity == null &&
            previous?.parity != null) parity = previous!.parity! + 1;
        final r = DairyRecord(
            id: _newId('dairy'),
            kind: kind,
            day: day,
            recordedAt: now.toUtc(),
            recordedOn: DairyCalendar.day(now.toLocal()),
            note: note.trim(),
            phase: phase,
            sireId: sireId,
            relatedId: relatedId,
            calfId: calfId,
            pregnancy: pregnancy,
            confirmedConception: confirmedConception,
            parity: parity,
            safeUseDay: safeUseDay,
            supersedesId: supersedesId,
            healthRecordId: healthRecordId);
        final updated = c.copyWith(
            modules: TwinModules(
                beef: c.modules.beef,
                dairy: DairyExtension.withRecords(
                    records: [...d.records, r], milk: d.milk)));
        var animals = allCattle.map((a) => a.id == id ? updated : a).toList();
        if (kind == DairyRecordKind.calving && calfId != null) {
          final calf = byId(calfId);
          _requireActive(calf);
          final check = d.records.where((r) => r.id == relatedId).firstOrNull;
          final service =
              d.records.where((r) => r.id == check?.relatedId).firstOrNull;
          final sire = service?.sireId;
          if (calf!.core.references.damId != null &&
                  calf.core.references.damId != id ||
              sire != null &&
                  calf.core.references.sireId != null &&
                  calf.core.references.sireId != sire) {
            throw StateError('Referensi anak berbeda; histori tidak ditimpa.');
          }
          final refs = calf.core.references;
          final linked = calf.copyWith(
              core: calf.core.copyWith(
                  references: TwinReferences(
                      damId: id,
                      sireId: sire ?? refs.sireId,
                      externalIds: refs.externalIds)));
          animals = animals.map((a) => a.id == calfId ? linked : a).toList();
        }
        return _withCattle(animals);
      });

  Future<void> recordStock(
          {required String feed,
          required StockMovement kind,
          required double kg,
          required String note,
          int? expectedRevision,
          String? expectedFarmId}) =>
      _commit(() {
        _expectFarm(expectedFarmId);
        if (expectedRevision != null && feedStock.length != expectedRevision) {
          throw StateError('Stok berubah. Buka kembali form.');
        }
        return _snapshot.copyWith(feedStock: [
          ...feedStock,
          StockEntry(
              id: _newId('stock'),
              feed: feed,
              kind: kind,
              kg: kg,
              recordedAt: _now().toUtc(),
              note: note.trim())
        ]);
      });

  Future<void> settings(String name, String farmName, int days,
          {FarmProductionSystems? productionSystems,
          String? expectedRevision}) =>
      _commit(
        () {
          if (expectedRevision != null &&
              expectedRevision != settingsRevision) {
            throw StateError(
                'Preferensi farm berubah. Buka kembali pengaturan sebelum menyimpan.');
          }
          _checkProductionSystems(productionSystems);
          if (name.trim().isEmpty ||
              name.trim().length > 40 ||
              farmName.trim().isEmpty ||
              farmName.trim().length > 70 ||
              !CattleRules.reminderIntervals.contains(days)) {
            throw ArgumentError('Preferensi peternakan tidak valid.');
          }
          return _snapshot.copyWith(
            productionSystems: productionSystems,
            farmer: name.trim(),
            farm: farmName.trim(),
            reminderDays: days,
            cattle: allCattle,
            feedPlans: feedPlans,
          );
        },
      );
  Map<String, dynamic> exportData() {
    if (!_ready || _snapshot.farmId.isEmpty) {
      throw StateError('Data peternakan belum tersedia untuk dicadangkan.');
    }
    return FarmBackupCodec.encode(_snapshot, exportedAt: _now());
  }

  Future<void> restoreBackup(String raw) async {
    final restored = FarmBackupCodec.decode(raw, migratedAt: _now());
    await _commit(() => restored, recovering: true);
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
