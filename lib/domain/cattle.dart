import 'condition.dart';
import 'records.dart';
import 'value.dart';

class Cattle {
  Cattle(
      {required this.id,
      required this.name,
      required this.sex,
      required this.ageMonths,
      required this.createdAt,
      required this.updatedAt,
      this.userId = '',
      this.archivedAt,
      List<WeightRecord> weights = const [],
      List<CattlePhoto> photos = const [],
      List<ConditionRecord> conditions = const [],
      List<MilkRecord> milk = const [],
      List<DairyEvent> events = const [],
      List<NutritionEvaluation> evaluations = const []})
      : weights = List.unmodifiable(weights),
        photos = List.unmodifiable(photos),
        conditions = List.unmodifiable(conditions),
        milk = List.unmodifiable(milk),
        events = List.unmodifiable(events),
        evaluations = List.unmodifiable(evaluations);
  final String id, name, userId;
  final Sex sex;
  final int ageMonths;
  final DateTime createdAt, updatedAt;
  final DateTime? archivedAt;
  final List<WeightRecord> weights;
  final List<CattlePhoto> photos;
  final List<ConditionRecord> conditions;
  final List<MilkRecord> milk;
  final List<DairyEvent> events;
  final List<NutritionEvaluation> evaluations;
  bool get active => archivedAt == null;
  WeightRecord get latestWeight => weights.last;
  Condition get condition => conditions.last.value;
  Cattle copy(
          {String? name,
          String? userId,
          Sex? sex,
          int? ageMonths,
          DateTime? updatedAt,
          DateTime? archivedAt,
          bool restore = false,
          List<WeightRecord>? weights,
          List<CattlePhoto>? photos,
          List<ConditionRecord>? conditions,
          List<MilkRecord>? milk,
          List<DairyEvent>? events,
          List<NutritionEvaluation>? evaluations}) =>
      Cattle(
          id: id,
          name: name ?? this.name,
          userId: userId ?? this.userId,
          sex: sex ?? this.sex,
          ageMonths: ageMonths ?? this.ageMonths,
          createdAt: createdAt,
          updatedAt: updatedAt ?? this.updatedAt,
          archivedAt: restore ? null : archivedAt ?? this.archivedAt,
          weights: weights ?? this.weights,
          photos: photos ?? this.photos,
          conditions: conditions ?? this.conditions,
          milk: milk ?? this.milk,
          events: events ?? this.events,
          evaluations: evaluations ?? this.evaluations);
  Json toJson() => {
        'id': id,
        'name': name,
        'userId': userId,
        'sex': sex.name,
        'ageMonths': ageMonths,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'archivedAt': archivedAt?.toIso8601String(),
        'weights': weights.map((e) => e.toJson()).toList(),
        'photos': photos.map((e) => e.toJson()).toList(),
        'conditions': conditions.map((e) => e.toJson()).toList(),
        'milk': milk.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'evaluations': evaluations.map((e) => e.toJson()).toList()
      };
  factory Cattle.fromJson(Json j) {
    known(j, {
      'id',
      'name',
      'userId',
      'sex',
      'ageMonths',
      'createdAt',
      'updatedAt',
      'archivedAt',
      'weights',
      'photos',
      'conditions',
      'milk',
      'events',
      'evaluations'
    });
    return Cattle(
        id: j['id'] as String,
        name: j['name'] as String,
        userId: j['userId'] as String,
        sex: Sex.values.byName(j['sex'] as String),
        ageMonths: j['ageMonths'] as int,
        createdAt: instant(j['createdAt']),
        updatedAt: instant(j['updatedAt']),
        archivedAt: j['archivedAt'] == null ? null : instant(j['archivedAt']),
        weights: records(j['weights'], WeightRecord.fromJson),
        photos: records(j['photos'], CattlePhoto.fromJson),
        conditions: records(j['conditions'], ConditionRecord.fromJson),
        milk: records(j['milk'], MilkRecord.fromJson),
        events: records(j['events'], DairyEvent.fromJson),
        evaluations: records(j['evaluations'], NutritionEvaluation.fromJson));
  }
}

class FarmAccount {
  const FarmAccount(
      {required this.id,
      required this.mode,
      required this.createdAt,
      required this.updatedAt,
      this.owner = 'Peternak',
      this.farmName = 'Peternakan saya'});
  final String id, owner, farmName;
  final FarmMode mode;
  final DateTime createdAt, updatedAt;
  Json toJson() => {
        'id': id,
        'mode': mode.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'owner': owner,
        'farmName': farmName
      };
  factory FarmAccount.fromJson(Json j) {
    known(j, {'id', 'mode', 'createdAt', 'updatedAt', 'owner', 'farmName'});
    return FarmAccount(
        id: j['id'] as String,
        mode: FarmMode.values.byName(j['mode'] as String),
        createdAt: instant(j['createdAt']),
        updatedAt: instant(j['updatedAt']),
        owner: j['owner'] as String,
        farmName: j['farmName'] as String);
  }
}

class FarmData {
  FarmData({this.account, this.revision = 0, List<Cattle> cattle = const []})
      : cattle = List.unmodifiable(cattle);
  final FarmAccount? account;
  final int revision;
  final List<Cattle> cattle;
  Iterable<Cattle> get active => cattle.where((c) => c.active);
  Cattle? find(String id) => cattle.where((c) => c.id == id).firstOrNull;
  FarmData replace(Cattle value) =>
      FarmData(account: account, revision: revision + 1, cattle: [
        for (final c in cattle)
          if (c.id == value.id) value else c
      ]);
  Json toJson() => {
        'account': account?.toJson(),
        'revision': revision,
        'cattle': cattle.map((e) => e.toJson()).toList()
      };
  factory FarmData.fromJson(Json j) {
    known(j, {'account', 'revision', 'cattle'});
    return FarmData(
        account: j['account'] == null
            ? null
            : FarmAccount.fromJson(object(j['account'])),
        revision: j['revision'] as int,
        cattle: records(j['cattle'], Cattle.fromJson));
  }
}
