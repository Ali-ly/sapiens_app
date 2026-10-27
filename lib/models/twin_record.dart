import 'persisted_time.dart';
import 'production.dart';

/// Shared events contain no Beef/Dairy calculation rules or clinical thresholds.
enum CattleStatus {
  active,
  sold,
  culled,
  slaughtered,
  transferred,
  deceased,
  archived
}

enum LifeStage { calf, youngstock, adult }

enum HealthKind {
  observation,
  treatment,
  vaccination,
  deworming,
  preventiveCare
}

enum TwinEventKind {
  weightRecorded,
  photosAdded,
  statusChanged,
  lifeStageChanged,
  healthRecorded,
  productionCategoryChanged
}

class StatusRecord {
  const StatusRecord(
      {required this.id,
      required this.recordedAt,
      this.recordedAtText,
      required this.status,
      this.note = ''});
  final String id;
  final DateTime recordedAt;
  final String? recordedAtText;
  final CattleStatus status;
  final String note;
  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': PersistedTime.encode(recordedAt, recordedAtText),
        'status': status.name,
        'note': note
      };
}

class LifeStageRecord {
  const LifeStageRecord(
      {required this.id,
      required this.recordedAt,
      this.recordedAtText,
      required this.stage,
      this.note = ''});
  final String id;
  final DateTime recordedAt;
  final String? recordedAtText;
  final LifeStage stage;
  final String note;
  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': PersistedTime.encode(recordedAt, recordedAtText),
        'stage': stage.name,
        'note': note
      };
}

class HealthRecord {
  const HealthRecord(
      {required this.id,
      required this.recordedAt,
      this.recordedAtText,
      required this.occurredAt,
      this.occurredAtText,
      this.nextDueAtText,
      required this.kind,
      required this.note,
      this.nextDueAt});
  final String id;
  final DateTime recordedAt, occurredAt;
  final String? recordedAtText, occurredAtText, nextDueAtText;
  final HealthKind kind;
  final String note;
  final DateTime? nextDueAt;
  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': PersistedTime.encode(recordedAt, recordedAtText),
        'occurredAt': PersistedTime.encode(occurredAt, occurredAtText),
        'kind': kind.name,
        'note': note,
        if (nextDueAt != null)
          'nextDueAt': PersistedTime.encode(nextDueAt!, nextDueAtText)
      };
}

/// References the existing gallery without duplicating photo bytes in history.
class PhotoRecord {
  const PhotoRecord(
      {required this.id,
      required this.recordedAt,
      this.recordedAtText,
      required this.imageIndex,
      required this.source,
      this.weightRecordId,
      this.mediaId});
  final String id;
  final DateTime recordedAt;
  final String? recordedAtText;
  final int imageIndex;
  final String source;
  final String? weightRecordId;
  final String? mediaId;
  PhotoRecord withMediaId(String value) => PhotoRecord(
      id: id,
      recordedAt: recordedAt,
      recordedAtText: recordedAtText,
      imageIndex: imageIndex,
      source: source,
      weightRecordId: weightRecordId,
      mediaId: value);
  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': PersistedTime.encode(recordedAt, recordedAtText),
        'imageIndex': imageIndex,
        'source': source,
        if (weightRecordId != null) 'weightRecordId': weightRecordId,
        if (mediaId != null) 'mediaId': mediaId
      };
}

class TwinEvent {
  const TwinEvent(
      {required this.id,
      required this.recordedAt,
      this.recordedAtText,
      required this.kind,
      this.recordId,
      this.previousCategory,
      this.productionCategory,
      this.note = ''});
  final String id;
  final DateTime recordedAt;
  final String? recordedAtText;
  final TwinEventKind kind;
  final String? recordId;
  final ProductionCategory? previousCategory, productionCategory;
  final String note;
  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': PersistedTime.encode(recordedAt, recordedAtText),
        'kind': kind.name,
        if (recordId != null) 'recordId': recordId,
        if (previousCategory != null)
          'previousCategory': previousCategory!.name,
        if (productionCategory != null)
          'productionCategory': productionCategory!.name,
        'note': note
      };
}

extension CattleStatusLabel on CattleStatus {
  String get label => switch (this) {
        CattleStatus.active => 'Aktif',
        CattleStatus.sold => 'Terjual',
        CattleStatus.culled => 'Afkir',
        CattleStatus.slaughtered => 'Dipotong',
        CattleStatus.transferred => 'Dipindahkan',
        CattleStatus.deceased => 'Mati',
        CattleStatus.archived => 'Diarsipkan',
      };
}
