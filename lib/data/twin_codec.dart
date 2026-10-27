import '../models/cattle.dart';
import '../models/persisted_time.dart';

/// Shared foundation versions 1 (legacy) and 2 (schema 5). Unknown fields must
/// never be silently discarded when a newer backup is opened by this reader.
class TwinCodec {
  static Map<String, dynamic> encode(Cattle c) => {
        'version': 2,
        'ageEvidence': c.core.identity.ageEvidence.toJson(),
        if (c.productionCategory != null)
          'productionCategory': c.productionCategory!.name,
        'statuses': c.core.lifecycle.statuses.map((r) => r.toJson()).toList(),
        'stages': c.core.lifecycle.stages.map((r) => r.toJson()).toList(),
        'health': c.core.health.map((r) => r.toJson()).toList(),
        'photos': c.core.photos.history.map((r) => r.toJson()).toList(),
        'timeline': c.core.timeline.map((r) => r.toJson()).toList(),
        'references': c.core.references.toJson(),
        'modules': {
          if (c.modules.beef != null) 'beef': c.modules.beef!.toJson(),
          if (c.modules.dairy != null) 'dairy': c.modules.dairy!.toJson(),
        },
      };

  static bool hasFoundation(Cattle c) =>
      c.productionCategory != null ||
      c.core.lifecycle.statuses.isNotEmpty ||
      c.core.lifecycle.stages.isNotEmpty ||
      c.core.health.isNotEmpty ||
      c.core.photos.history.isNotEmpty ||
      c.core.timeline.isNotEmpty ||
      c.core.references.damId != null ||
      c.core.references.sireId != null ||
      c.core.references.externalIds.isNotEmpty ||
      c.modules.beef != null ||
      c.modules.dairy != null ||
      c.history.any((r) => r.id != null);

  static Cattle decode(Cattle legacy, Object? raw, {int expectedVersion = 2}) {
    if (raw == null) return legacy;
    final j = object(raw, {
      'version',
      if (expectedVersion >= 2) 'ageEvidence',
      'productionCategory',
      'statuses',
      'stages',
      'health',
      'photos',
      'timeline',
      'references',
      'modules'
    });
    version(j, expected: expectedVersion);
    final statuses = records(j['statuses'], (r) {
      fields(r, {'id', 'recordedAt', 'status', 'note'});
      return StatusRecord(
          id: r['id'] as String,
          recordedAt: date(r['recordedAt']),
          recordedAtText: r['recordedAt'] as String,
          status: CattleStatus.values.byName(r['status'] as String),
          note: r['note'] as String);
    });
    final stages = records(j['stages'], (r) {
      fields(r, {'id', 'recordedAt', 'stage', 'note'});
      return LifeStageRecord(
          id: r['id'] as String,
          recordedAt: date(r['recordedAt']),
          recordedAtText: r['recordedAt'] as String,
          stage: LifeStage.values.byName(r['stage'] as String),
          note: r['note'] as String);
    });
    final health = records(j['health'], (r) {
      fields(
          r, {'id', 'recordedAt', 'occurredAt', 'kind', 'note', 'nextDueAt'});
      return HealthRecord(
          id: r['id'] as String,
          recordedAt: date(r['recordedAt']),
          recordedAtText: r['recordedAt'] as String,
          occurredAt: date(r['occurredAt']),
          occurredAtText: r['occurredAt'] as String,
          nextDueAtText: r['nextDueAt'] as String?,
          kind: HealthKind.values.byName(r['kind'] as String),
          note: r['note'] as String,
          nextDueAt: r['nextDueAt'] == null ? null : date(r['nextDueAt']));
    });
    final photos = records(j['photos'], (r) {
      fields(r, {
        'id',
        'recordedAt',
        'imageIndex',
        'source',
        'weightRecordId',
        if (expectedVersion >= 2) 'mediaId'
      });
      return PhotoRecord(
          id: r['id'] as String,
          recordedAt: date(r['recordedAt']),
          recordedAtText: r['recordedAt'] as String,
          imageIndex: r['imageIndex'] as int,
          source: r['source'] as String,
          weightRecordId: r['weightRecordId'] as String?,
          mediaId: r['mediaId'] as String?);
    });
    final timeline = records(j['timeline'], (r) {
      fields(r, {
        'id',
        'recordedAt',
        'kind',
        'recordId',
        'note',
        'previousCategory',
        'productionCategory'
      });
      return TwinEvent(
          id: r['id'] as String,
          recordedAt: date(r['recordedAt']),
          recordedAtText: r['recordedAt'] as String,
          kind: TwinEventKind.values.byName(r['kind'] as String),
          recordId: r['recordId'] as String?,
          previousCategory: r['previousCategory'] == null
              ? null
              : ProductionCategory.values
                  .byName(r['previousCategory'] as String),
          productionCategory: r['productionCategory'] == null
              ? null
              : ProductionCategory.values
                  .byName(r['productionCategory'] as String),
          note: r['note'] as String);
    });
    final refs = object(j['references'], {'damId', 'sireId', 'externalIds'});
    final external = Map<String, String>.from(refs['externalIds'] as Map);
    final modules = object(j['modules'], {'beef', 'dairy'});
    DairyExtension? dairy;
    if (modules.containsKey('dairy')) {
      final m = object(modules['dairy'], {'version', 'records', 'milk'});
      if (m['version'] == 1) {
        fields(m, {'version'});
        dairy = const DairyExtension();
      } else {
        version(m, expected: 2);
        dairy = DairyExtension.withRecords(
            records: records(m['records'], DairyRecord.fromJson),
            milk: records(m['milk'], MilkRecord.fromJson));
      }
    }
    BeefExtension? beef;
    if (modules.containsKey('beef')) {
      final m = object(modules['beef'], {'version', 'records'});
      if (m['version'] == 1) {
        fields(m, {'version'});
        beef = const BeefExtension();
      } else {
        version(m, expected: 2);
        beef = BeefExtension.withRecords(
            records(m['records'], BeefRecord.fromJson));
      }
    }
    return legacy.copyWith(
      ageEvidence: expectedVersion >= 2
          ? AgeEvidence.fromJson(
              Map<String, dynamic>.from(j['ageEvidence'] as Map))
          : const AgeEvidence(),
      productionCategory: j['productionCategory'] == null
          ? null
          : ProductionCategory.values.byName(j['productionCategory'] as String),
      modules: TwinModules(beef: beef, dairy: dairy),
      core: legacy.core.copyWith(
        lifecycle: TwinLifecycle(statuses: statuses, stages: stages),
        health: health,
        timeline: timeline,
        photos: TwinPhotos(images: legacy.images, history: photos),
        references: TwinReferences(
            damId: refs['damId'] as String?,
            sireId: refs['sireId'] as String?,
            externalIds: external),
      ),
    );
  }

  static DateTime date(Object? value) => PersistedTime.parse(value as String);
  static void version(Map<String, dynamic> j, {int expected = 1}) {
    if (j['version'] is! int || j['version'] != expected) {
      throw const FormatException('Versi fondasi Twin belum didukung.');
    }
  }

  static void fields(Map<String, dynamic> j, Set<String> allowed) {
    if (j.keys.any((k) => !allowed.contains(k))) {
      throw const FormatException(
          'Data fondasi Twin memuat field yang belum didukung.');
    }
  }

  static Map<String, dynamic> object(Object? raw, Set<String> allowed) {
    final j = Map<String, dynamic>.from(raw as Map);
    fields(j, allowed);
    return j;
  }

  static List<T> records<T>(
          Object? raw, T Function(Map<String, dynamic>) parse) =>
      (raw as List)
          .map((r) => parse(Map<String, dynamic>.from(r as Map)))
          .toList();
}
