import 'dart:convert';
import 'dart:typed_data';

import 'value.dart';

enum WeightSource { manual, photoEstimation }

class WeightRecord {
  WeightRecord(
      {required this.id,
      required this.kg,
      required this.source,
      required this.measuredAt,
      List<String> photoIds = const [],
      Json quality = const {}})
      : photoIds = List.unmodifiable(photoIds),
        quality = frozenJson(quality);
  final String id;
  final double kg;
  final WeightSource source;
  final DateTime measuredAt;
  final List<String> photoIds;
  final Json quality;
  Json toJson() => {
        'id': id,
        'kg': kg,
        'source': source.name,
        'measuredAt': measuredAt.toIso8601String(),
        'photoIds': photoIds,
        'quality': quality
      };
  factory WeightRecord.fromJson(Json j) {
    known(j, {'id', 'kg', 'source', 'measuredAt', 'photoIds', 'quality'});
    return WeightRecord(
        id: j['id'] as String,
        kg: (j['kg'] as num).toDouble(),
        source: WeightSource.values.byName(j['source'] as String),
        measuredAt: instant(j['measuredAt']),
        photoIds: List<String>.from(j['photoIds'] as List),
        quality: object(j['quality']));
  }
}

class CattlePhoto {
  CattlePhoto(
      {required this.id,
      required this.name,
      required List<int> bytes,
      required this.addedAt,
      this.weightId})
      : _bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final String id, name;
  final Uint8List _bytes;
  Uint8List get bytes => _bytes;
  final DateTime addedAt;
  final String? weightId;
  Json toJson() => {
        'id': id,
        'name': name,
        'bytes': base64Encode(_bytes),
        'addedAt': addedAt.toIso8601String(),
        'weightId': weightId
      };
  factory CattlePhoto.fromJson(Json j) {
    known(j, {'id', 'name', 'bytes', 'addedAt', 'weightId'});
    return CattlePhoto(
        id: j['id'] as String,
        name: j['name'] as String,
        bytes: base64Decode(j['bytes'] as String),
        addedAt: instant(j['addedAt']),
        weightId: j['weightId'] as String?);
  }
}

enum MilkMode { totalDaily, amPm }

enum MilkUnit { kg, liter }

extension MilkUnitLabel on MilkUnit {
  String get label => this == MilkUnit.kg ? 'kg' : 'liter';
}

class MilkRecord {
  const MilkRecord(
      {required this.id,
      required this.date,
      required this.mode,
      required this.unit,
      required this.createdAt,
      this.total,
      this.am,
      this.pm,
      this.correctionOf});
  final String id, date;
  final MilkMode mode;
  final MilkUnit unit;
  final DateTime createdAt;
  final double? total, am, pm;
  final String? correctionOf;
  bool get complete =>
      mode == MilkMode.totalDaily ? total != null : am != null && pm != null;
  double get recordedAmount =>
      mode == MilkMode.totalDaily ? total! : (am ?? 0) + (pm ?? 0);
  Json toJson() => {
        'id': id,
        'date': date,
        'mode': mode.name,
        'unit': unit.name,
        'createdAt': createdAt.toIso8601String(),
        'total': total,
        'am': am,
        'pm': pm,
        'correctionOf': correctionOf
      };
  factory MilkRecord.fromJson(Json j) {
    known(j, {
      'id',
      'date',
      'mode',
      'unit',
      'createdAt',
      'total',
      'am',
      'pm',
      'correctionOf'
    });
    return MilkRecord(
        id: j['id'] as String,
        date: j['date'] as String,
        mode: MilkMode.values.byName(j['mode'] as String),
        unit: MilkUnit.values.byName(j['unit'] as String),
        createdAt: instant(j['createdAt']),
        total: (j['total'] as num?)?.toDouble(),
        am: (j['am'] as num?)?.toDouble(),
        pm: (j['pm'] as num?)?.toDouble(),
        correctionOf: j['correctionOf'] as String?);
  }
}

enum DairyEventKind {
  service,
  pregnancyCheck,
  confirmedConception,
  calving,
  withholding,
  udderObservation
}

extension DairyEventLabel on DairyEventKind {
  String get label => const [
        'Breeding / IB',
        'Pemeriksaan kebuntingan',
        'Konsepsi terkonfirmasi',
        'Kelahiran aktual',
        'Masa tahan susu',
        'Observasi ambing / susu'
      ][index];
}

class DairyEvent {
  const DairyEvent(
      {required this.id,
      required this.kind,
      required this.date,
      required this.createdAt,
      this.note = '',
      this.pregnancy,
      this.parity,
      this.until,
      this.relatedId});
  final String id, date, note;
  final DairyEventKind kind;
  final DateTime createdAt;
  final Pregnancy? pregnancy;
  final int? parity;
  final String? until, relatedId;
  Json toJson() => {
        'id': id,
        'kind': kind.name,
        'date': date,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'pregnancy': pregnancy?.name,
        'parity': parity,
        'until': until,
        'relatedId': relatedId
      };
  factory DairyEvent.fromJson(Json j) {
    known(j, {
      'id',
      'kind',
      'date',
      'createdAt',
      'note',
      'pregnancy',
      'parity',
      'until',
      'relatedId'
    });
    return DairyEvent(
        id: j['id'] as String,
        kind: DairyEventKind.values.byName(j['kind'] as String),
        date: j['date'] as String,
        createdAt: instant(j['createdAt']),
        note: j['note'] as String,
        pregnancy: j['pregnancy'] == null
            ? null
            : Pregnancy.values.byName(j['pregnancy'] as String),
        parity: j['parity'] as int?,
        until: j['until'] as String?,
        relatedId: j['relatedId'] as String?);
  }
}

class NutritionEvaluation {
  NutritionEvaluation(
      {required this.id,
      required this.createdAt,
      required this.contextHash,
      required Json request,
      required Json response,
      required Json contextSnapshot,
      Map<String, String> feedNames = const {}})
      : request = frozenJson(request),
        response = frozenJson(response),
        feedNames = Map.unmodifiable(feedNames),
        contextSnapshot = frozenJson(contextSnapshot);
  final String id, contextHash;
  final DateTime createdAt;
  final Json request, response, contextSnapshot;
  final Map<String, String> feedNames;
  Json toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'contextHash': contextHash,
        'request': request,
        'response': response,
        'feedNames': feedNames,
        'contextSnapshot': contextSnapshot
      };
  factory NutritionEvaluation.fromJson(Json j) {
    known(j, {
      'id',
      'createdAt',
      'contextHash',
      'request',
      'response',
      'feedNames',
      'contextSnapshot'
    });
    return NutritionEvaluation(
        id: j['id'] as String,
        createdAt: instant(j['createdAt']),
        contextHash: j['contextHash'] as String,
        request: object(j['request']),
        response: object(j['response']),
        contextSnapshot: object(j['contextSnapshot']),
        feedNames: Map<String, String>.from(j['feedNames'] as Map));
  }
}
