import 'age_evidence.dart';
import 'production.dart';
import 'selected_image.dart';
import 'twin_record.dart';
import 'weight_record.dart';

class TwinIdentity {
  const TwinIdentity(
      {required this.name,
      required this.gender,
      required this.ageMonths,
      this.notes = '',
      this.productionCategory,
      this.ageEvidence = const AgeEvidence()});
  final String name, gender, notes;
  final int ageMonths;
  final ProductionCategory? productionCategory;
  final AgeEvidence ageEvidence;
}

class TwinWeight {
  TwinWeight(
      {this.estimatedKg,
      this.predictionSpread,
      this.validImages = 0,
      this.rejectedImages = 0,
      List<WeightRecord> history = const []})
      : history = List.unmodifiable(history);
  final double? estimatedKg, predictionSpread;
  final int validImages, rejectedImages;
  final List<WeightRecord> history;
}

class TwinPhotos {
  TwinPhotos(
      {List<SelectedImage> images = const [],
      List<SelectedImage> latestCheckImages = const [],
      List<PhotoRecord> history = const []})
      : images = List.unmodifiable(images),
        latestCheckImages = List.unmodifiable(latestCheckImages),
        history = List.unmodifiable(history);
  final List<SelectedImage> images, latestCheckImages;
  final List<PhotoRecord> history;
}

class TwinLifecycle {
  TwinLifecycle(
      {List<StatusRecord> statuses = const [],
      List<LifeStageRecord> stages = const []})
      : statuses = List.unmodifiable(statuses),
        stages = List.unmodifiable(stages);
  final List<StatusRecord> statuses;
  final List<LifeStageRecord> stages;
  CattleStatus get status =>
      statuses.isEmpty ? CattleStatus.active : statuses.last.status;
  LifeStage? get stage => stages.isEmpty ? null : stages.last.stage;
}

class TwinReferences {
  TwinReferences(
      {this.damId, this.sireId, Map<String, String> externalIds = const {}})
      : externalIds = Map.unmodifiable(externalIds);
  final String? damId, sireId;
  final Map<String, String> externalIds;
  Map<String, dynamic> toJson() => {
        if (damId != null) 'damId': damId,
        if (sireId != null) 'sireId': sireId,
        'externalIds': externalIds
      };
}

/// Shared composition; domain-specific features belong in TwinModules.
class SharedTwinCore {
  SharedTwinCore(
      {required this.identity,
      TwinWeight? weight,
      TwinPhotos? photos,
      TwinLifecycle? lifecycle,
      TwinReferences? references,
      List<HealthRecord> health = const [],
      List<TwinEvent> timeline = const []})
      : weight = weight ?? TwinWeight(),
        photos = photos ?? TwinPhotos(),
        lifecycle = lifecycle ?? TwinLifecycle(),
        references = references ?? TwinReferences(),
        health = List.unmodifiable(health),
        timeline = List.unmodifiable(timeline);
  final TwinIdentity identity;
  final TwinWeight weight;
  final TwinPhotos photos;
  final TwinLifecycle lifecycle;
  final TwinReferences references;
  final List<HealthRecord> health;
  final List<TwinEvent> timeline;
  SharedTwinCore copyWith(
          {TwinIdentity? identity,
          TwinWeight? weight,
          TwinPhotos? photos,
          TwinLifecycle? lifecycle,
          TwinReferences? references,
          List<HealthRecord>? health,
          List<TwinEvent>? timeline}) =>
      SharedTwinCore(
          identity: identity ?? this.identity,
          weight: weight ?? this.weight,
          photos: photos ?? this.photos,
          lifecycle: lifecycle ?? this.lifecycle,
          references: references ?? this.references,
          health: health ?? this.health,
          timeline: timeline ?? this.timeline);
}
