import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/cattle_draft.dart';
import '../models/feed_plan.dart';
import '../models/selected_image.dart';
import 'local_storage.dart' as storage;

class FarmStore extends ChangeNotifier {
  FarmStore({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  })  : _read = read ?? storage.readData,
        _write = write ?? storage.writeData;
  static FarmStore instance = FarmStore();
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  List<CattleDraft> cattle = [];
  List<FeedPlan> feedPlans = [];
  FeedPlan? latestPlan(String cattleId) {
    final plans = feedPlans.where((p) => p.cattleId == cattleId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return plans.isEmpty ? null : plans.first;
  }

  bool planReady(CattleDraft c) =>
      latestPlan(c.id)?.matches(c) == true && !needsCheck(c);
  Map<String, double> get dailyFeedTotals {
    final totals = <String, double>{};
    for (final c in cattle.where(planReady)) {
      for (final portion in latestPlan(c.id)!.portions) {
        totals.update(portion.key, (n) => n + portion.asFedKg,
            ifAbsent: () => portion.asFedKg);
      }
    }
    return totals;
  }

  Future<void> savePlan(FeedPlan plan) =>
      _commit(() => [...cattle], buildPlans: () {
        final c = byId(plan.cattleId);
        if (c == null || !plan.matches(c))
          throw StateError(
              'Data sapi berubah. Hitung ulang pakan dengan bobot terbaru.');
        return [...feedPlans.where((p) => p.id != plan.id), plan];
      });
  String farmer = 'Peternak';
  String farm = 'Peternakan Saya';
  int reminderDays = 7;
  bool demo = false;
  bool ready = false;
  String? error;
  Future<void> _pending = Future.value();
  int _idCounter = 0;
  Future<void> load() async {
    error = null;
    try {
      final raw = await _read();
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final loadedPlans = (data['feedPlans'] as List? ?? [])
            .map((p) => FeedPlan.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        final loadedFarmer = data['farmer'] as String;
        final loadedFarm = data['farm'] as String;
        final loadedDays = data['reminderDays'] as int;
        if (![3, 7, 14, 30].contains(loadedDays))
          throw const FormatException('Interval pengecekan tidak valid.');
        final loadedCattle = (data['cattle'] as List)
            .map((e) => decodeCattle(Map<String, dynamic>.from(e)))
            .toList();
        farmer = loadedFarmer;
        farm = loadedFarm;
        reminderDays = loadedDays;
        cattle = loadedCattle;
        feedPlans = loadedPlans;
        demo = loadedCattle.any((c) => c.id.startsWith('demo-'));
      }
    } catch (_) {
      error =
          'Data lokal belum bisa dibaca. Data lama tidak akan ditimpa; muat ulang aplikasi untuk mencoba lagi.';
    }
    ready = true;
    notifyListeners();
  }

  CattleDraft? byId(String id) {
    for (final c in cattle) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool needsCheck(CattleDraft c) =>
      c.history.isEmpty ||
      DateTime.now().difference(c.history.last.date).inDays >= reminderDays;
  int get checksThisWeek => cattle.fold(
        0,
        (n, c) =>
            n +
            c.history
                .where((r) => DateTime.now().difference(r.date).inDays < 7)
                .length,
      );
  double get totalWeight =>
      cattle.fold(0.0, (n, c) => n + (c.estimatedWeight ?? 0));
  Future<void> _commit(
    List<CattleDraft> Function() buildNext, {
    String? name,
    String? farmName,
    int? days,
    bool? isDemo,
    List<FeedPlan> Function()? buildPlans,
    bool recovering = false,
  }) {
    final operation = _pending.then((_) async {
      if (error != null && !recovering) throw StateError(error!);
      final next = buildNext();
      final nextPlans = (buildPlans?.call() ?? feedPlans)
          .where((p) => next.any((c) => c.id == p.cattleId))
          .toList();
      final data = {
        'farmer': name ?? farmer,
        'farm': farmName ?? farm,
        'reminderDays': days ?? reminderDays,
        'demo': isDemo ?? next.any((c) => c.id.startsWith('demo-')),
        'cattle': next.map(encodeCattle).toList(),
        'feedPlans': nextPlans.map((p) => p.toJson()).toList(),
      };
      await _write(jsonEncode(data));
      error = null;
      cattle = next;
      feedPlans = nextPlans;
      farmer = name ?? farmer;
      farm = farmName ?? farm;
      reminderDays = days ?? reminderDays;
      demo = isDemo ?? next.any((c) => c.id.startsWith('demo-'));
      notifyListeners();
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<CattleDraft> save(CattleDraft value) async {
    final weight = value.estimatedWeight;
    if (value.nameOrId.trim().isEmpty ||
        value.ageMonths < 1 ||
        value.ageMonths > 360 ||
        !['Jantan', 'Betina'].contains(value.gender))
      throw StateError('Identitas sapi tidak valid.');
    if (weight != null && (!weight.isFinite || weight < 1 || weight > 2000))
      throw StateError('Bobot dari layanan tidak valid (harus 1–2.000 kg).');
    final saved = value.id.isEmpty
        ? value.copyWith(
            id: '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}')
        : value;
    await _commit(() {
      if (cattle.any(
        (c) =>
            c.id != value.id &&
            c.nameOrId.toLowerCase() == value.nameOrId.toLowerCase(),
      )) throw StateError('Nama / ID sapi sudah digunakan.');
      return [...cattle.where((c) => c.id != saved.id), saved];
    });
    return saved;
  }

  Future<CattleDraft> updateIdentity(String id,
      {required String name,
      required String gender,
      required int ageMonths,
      required String notes}) async {
    late CattleDraft updated;
    await _commit(() {
      final current = byId(id);
      if (current == null)
        throw StateError(
            'Sapi ini sudah tidak tersedia. Kembali ke daftar sapi.');
      final label = name.trim();
      if (label.isEmpty ||
          label.length > 60 ||
          ageMonths < 1 ||
          ageMonths > 360 ||
          !['Jantan', 'Betina'].contains(gender) ||
          notes.length > 500) throw StateError('Identitas sapi tidak valid.');
      if (cattle.any((c) =>
          c.id != id && c.nameOrId.trim().toLowerCase() == label.toLowerCase()))
        throw StateError('Nama / ID sapi sudah digunakan.');
      updated = current.copyWith(
          nameOrId: label,
          gender: gender,
          ageMonths: ageMonths,
          notes: notes.trim());
      return cattle.map((c) => c.id == id ? updated : c).toList();
    });
    return updated;
  }

  Future<void> removeExamples() =>
      _commit(() => cattle.where((c) => !c.id.startsWith('demo-')).toList());

  Future<void> remove(String id) =>
      _commit(() => cattle.where((c) => c.id != id).toList());
  Future<void> settings(String name, String farmName, int days) =>
      _commit(() => [...cattle], name: name, farmName: farmName, days: days);
  Future<void> addExamples() async {
    if (cattle.isNotEmpty) return;
    final now = DateTime.now();
    await _commit(
      () => cattle.isNotEmpty
          ? [...cattle]
          : List.generate(5, (i) {
              final weight = [348.0, 312.0, 285.0, 401.0, 267.0][i];
              final ago = [1, 3, 5, 10, 7][i];
              return CattleDraft(
                id: 'demo-$i',
                nameOrId: [
                  'B001 - Budi',
                  'B002 - Sari',
                  'B003 - Jaya',
                  'B004 - Miko',
                  'B005 - Bima',
                ][i],
                gender: i == 1 ? 'Betina' : 'Jantan',
                ageMonths: 18 + i * 2,
                estimatedWeight: weight,
                notes: 'Data contoh untuk mencoba aplikasi.',
                history: List.generate(
                  4,
                  (j) => WeightRecord(
                    weightKg: weight - (3 - j) * 9,
                    source: 'demo',
                    date: now.subtract(Duration(days: ago + (3 - j) * 14)),
                  ),
                ),
              );
            }),
    );
  }

  Map<String, dynamic> exportData() => {
        'schemaVersion': 2,
        'farmer': farmer,
        'farm': farm,
        'reminderDays': reminderDays,
        'exportedAt': DateTime.now().toIso8601String(),
        'cattle': cattle.map(encodeCattle).toList(),
        'feedPlans': feedPlans.map((p) => p.toJson()).toList()
      };
  static Map<String, dynamic> validateBackup(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>)
        throw const FormatException('Format cadangan tidak dikenali.');
      if (decoded['schemaVersion'] != null && decoded['schemaVersion'] != 2)
        throw const FormatException('Versi cadangan belum didukung.');
      final items = (decoded['cattle'] as List)
          .map((e) => decodeCattle(Map<String, dynamic>.from(e)))
          .toList();
      final ids = <String>{}, names = <String>{};
      for (final c in items) {
        if (c.id.isEmpty ||
            !ids.add(c.id) ||
            c.nameOrId.trim().isEmpty ||
            !names.add(c.nameOrId.toLowerCase()) ||
            c.ageMonths < 1 ||
            c.ageMonths > 360 ||
            !['Jantan', 'Betina'].contains(c.gender))
          throw const FormatException(
              'Identitas sapi dalam cadangan tidak valid atau duplikat.');
        final w = c.estimatedWeight;
        if (w != null && (!w.isFinite || w < 1 || w > 2000))
          throw const FormatException('Bobot dalam cadangan tidak valid.');
        DateTime? last;
        for (final r in c.history) {
          if (!r.weightKg.isFinite ||
              r.weightKg < 1 ||
              r.weightKg > 2000 ||
              last != null && r.date.isBefore(last))
            throw const FormatException(
                'Riwayat bobot dalam cadangan tidak valid.');
          last = r.date;
        }
      }
      final plans = (decoded['feedPlans'] as List? ?? [])
          .map((e) => FeedPlan.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final planIds = <String>{};
      for (final p in plans) {
        if (!ids.contains(p.cattleId) ||
            !planIds.add(p.id) ||
            !p.weightKg.isFinite ||
            p.weightKg < 1 ||
            p.portions.isEmpty ||
            p.portions.any((r) => !r.asFedKg.isFinite || r.asFedKg < 0) ||
            !targetLabels.containsKey(p.target))
          throw const FormatException(
              'Rencana pakan dalam cadangan tidak valid.');
      }
      if (decoded['farmer'] is! String ||
          (decoded['farmer'] as String).trim().isEmpty ||
          decoded['farm'] is! String ||
          (decoded['farm'] as String).trim().isEmpty)
        throw const FormatException(
            'Identitas peternakan dalam cadangan tidak lengkap.');
      final days = decoded['reminderDays'] ?? 7;
      if (days is! int || ![3, 7, 14, 30].contains(days))
        throw const FormatException('Interval pengecekan tidak valid.');
      return {...decoded, 'reminderDays': days};
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'Cadangan tidak dapat dibaca. Gunakan JSON hasil ekspor SAPITA.');
    }
  }

  Future<void> restoreBackup(String raw) async {
    final data = validateBackup(raw);
    final items = (data['cattle'] as List)
        .map((e) => decodeCattle(Map<String, dynamic>.from(e)))
        .toList();
    final plans = (data['feedPlans'] as List? ?? [])
        .map((e) => FeedPlan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    await _commit(() => items,
        buildPlans: () => plans,
        name: data['farmer'],
        farmName: data['farm'],
        days: data['reminderDays'],
        recovering: true);
  }

  static Map<String, dynamic> encodeCattle(CattleDraft c) => {
        'id': c.id,
        'name': c.nameOrId,
        'gender': c.gender,
        'age': c.ageMonths,
        'notes': c.notes,
        'weight': c.estimatedWeight,
        'spread': c.predictionSpread,
        'valid': c.validImages,
        'rejected': c.rejectedImages,
        'history': c.history
            .map((r) => {
                  'weight': r.weightKg,
                  'date': r.date.toIso8601String(),
                  'source': r.source
                })
            .toList(),
        'images': c.images
            .map((i) => {'name': i.file.name, 'bytes': base64Encode(i.bytes)})
            .toList(),
      };
  static CattleDraft decodeCattle(Map<String, dynamic> d) => CattleDraft(
        id: d['id'],
        nameOrId: d['name'],
        gender: d['gender'],
        ageMonths: d['age'],
        notes: d['notes'],
        estimatedWeight: (d['weight'] as num?)?.toDouble(),
        predictionSpread: (d['spread'] as num?)?.toDouble(),
        validImages: d['valid'] ?? 0,
        rejectedImages: d['rejected'] ?? 0,
        history: (d['history'] as List)
            .map(
              (r) => WeightRecord(
                weightKg: (r['weight'] as num).toDouble(),
                date: DateTime.parse(r['date']),
                source: r['source'] ?? 'unknown',
              ),
            )
            .toList(),
        images: (d['images'] as List).map((i) {
          final bytes = base64Decode(i['bytes']);
          return SelectedImage(
            file: XFile.fromData(bytes, name: i['name']),
            bytes: bytes,
          );
        }).toList(),
      );
}
