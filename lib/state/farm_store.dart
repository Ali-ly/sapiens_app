import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/farm_backup_codec.dart';
import '../data/sample_cattle.dart';
import '../models/cattle.dart';
import '../models/cattle_rules.dart';
import '../models/farm_snapshot.dart';
import '../models/feed_plan.dart';
import '../models/feed_plan_rules.dart';
import '../models/selected_image.dart';
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

  List<Cattle> get cattle => _snapshot.cattle;
  List<FeedPlan> get feedPlans => _snapshot.feedPlans;
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
      final next = raw == null ? FarmSnapshot() : FarmBackupCodec.decode(raw);
      _snapshot = next;
    } catch (_) {
      _error =
          'Data lokal belum bisa dibaca. Data lama tidak akan ditimpa; muat ulang aplikasi untuk mencoba lagi.';
    }
    _ready = true;
    _notify();
  }

  Cattle? byId(String id) {
    for (final animal in cattle) {
      if (animal.id == id) {
        return animal;
      }
    }
    return null;
  }

  FeedPlan? latestPlan(String cattleId) {
    FeedPlan? latest;
    for (final plan in feedPlans) {
      if (plan.cattleId == cattleId &&
          (latest == null || !plan.createdAt.isBefore(latest.createdAt))) {
        latest = plan;
      }
    }
    return latest;
  }

  bool needsCheck(Cattle animal) =>
      animal.history.isEmpty ||
      _now().difference(animal.history.last.date).inDays >= reminderDays;
  bool planReady(Cattle animal) =>
      latestPlan(animal.id)?.matches(animal) == true && !needsCheck(animal);
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
        final next = build();
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

  FarmSnapshot _withCattle(List<Cattle> animals) => FarmSnapshot(
        farmer: farmer,
        farm: farm,
        reminderDays: reminderDays,
        cattle: animals,
        feedPlans: feedPlans
            .where(
              (plan) => animals.any((animal) => animal.id == plan.cattleId),
            )
            .toList(),
      );

  void _checkUniqueName(Cattle animal) {
    if (cattle.any(
      (other) =>
          other.id != animal.id &&
          other.nameOrId.trim().toLowerCase() ==
              animal.nameOrId.trim().toLowerCase(),
    )) {
      throw StateError('Nama / ID sapi sudah digunakan.');
    }
  }

  Future<Cattle> saveCattle(Cattle value) async {
    CattleRules.validate(value, requireId: false);
    final saved = value.copyWith(
      id: value.id.isEmpty
          ? '${_now().microsecondsSinceEpoch}-${_idCounter++}'
          : value.id,
      nameOrId: value.nameOrId.trim(),
    );
    await _commit(
      () {
        _checkUniqueName(saved);
        return _withCattle(
          [...cattle.where((animal) => animal.id != saved.id), saved],
        );
      },
    );
    return saved;
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
        if (current == null) {
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
          cattle.map((animal) => animal.id == id ? updated : animal).toList(),
        );
      },
    );
    return updated;
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
        if (current == null) {
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
        updated = current.copyWith(
          estimatedWeight: weightKg,
          clearPrediction: predictionSpread == null,
          predictionSpread: predictionSpread,
          validImages: validImages,
          rejectedImages: rejectedImages,
          images: [...current.images, ...images],
          latestCheckImages: images,
          history: [
            ...current.history,
            WeightRecord(weightKg: weightKg, date: _now(), source: source)
          ],
        );
        CattleRules.validate(updated);
        return _withCattle(
          cattle.map((animal) => animal.id == id ? updated : animal).toList(),
        );
      },
    );
    return updated;
  }

  Future<void> savePlan(FeedPlan plan) => _commit(
        () {
          FeedPlanRules.validate(plan);
          final animal = byId(plan.cattleId);
          if (animal == null || !plan.matches(animal)) {
            throw StateError(
              'Data sapi berubah. Hitung ulang pakan dengan bobot terbaru.',
            );
          }
          return FarmSnapshot(
            farmer: farmer,
            farm: farm,
            reminderDays: reminderDays,
            cattle: cattle,
            feedPlans: [
              ...feedPlans.where((other) => other.id != plan.id),
              plan
            ],
          );
        },
      );
  Future<void> remove(String id) => _commit(
        () => _withCattle(cattle.where((animal) => animal.id != id).toList()),
      );
  Future<void> removeExamples() => _commit(
        () => _withCattle(
          cattle.where((animal) => !animal.id.startsWith('demo-')).toList(),
        ),
      );
  Future<void> addExamples() => _commit(
        () => cattle.isEmpty
            ? _withCattle(createSampleCattle(_now()))
            : _snapshot,
      );

  Future<void> settings(String name, String farmName, int days) => _commit(
        () {
          if (name.trim().isEmpty ||
              name.trim().length > 40 ||
              farmName.trim().isEmpty ||
              farmName.trim().length > 70 ||
              !CattleRules.reminderIntervals.contains(days)) {
            throw ArgumentError('Preferensi peternakan tidak valid.');
          }
          return FarmSnapshot(
            farmer: name.trim(),
            farm: farmName.trim(),
            reminderDays: days,
            cattle: cattle,
            feedPlans: feedPlans,
          );
        },
      );
  Map<String, dynamic> exportData() =>
      FarmBackupCodec.encode(_snapshot, exportedAt: _now());
  Future<void> restoreBackup(String raw) async {
    final restored = FarmBackupCodec.decode(raw);
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
