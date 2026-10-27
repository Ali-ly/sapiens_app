import 'age_evidence.dart';
import 'production.dart';
import 'selected_image.dart';
import 'shared_twin_core.dart';
import 'twin_modules.dart';
import 'twin_record.dart';
import 'weight_record.dart';

export 'age_evidence.dart';
export 'production.dart';
export 'shared_twin_core.dart';
export 'twin_modules.dart';
export 'twin_record.dart';
export 'weight_record.dart';

class Cattle {
  Cattle({
    required String nameOrId,
    this.id = '',
    required String gender,
    required int ageMonths,
    String notes = '',
    List<SelectedImage> images = const [],
    List<SelectedImage> latestCheckImages = const [],
    double? estimatedWeight,
    double? predictionSpread,
    int validImages = 0,
    int rejectedImages = 0,
    List<WeightRecord> history = const [],
    ProductionCategory? productionCategory,
    AgeEvidence ageEvidence = const AgeEvidence(),
    this.modules = const TwinModules(),
  }) : core = SharedTwinCore(
          identity: TwinIdentity(
              name: nameOrId,
              gender: gender,
              ageMonths: ageMonths,
              notes: notes,
              productionCategory: productionCategory,
              ageEvidence: ageEvidence),
          weight: TwinWeight(
              estimatedKg: estimatedWeight,
              predictionSpread: predictionSpread,
              validImages: validImages,
              rejectedImages: rejectedImages,
              history: history),
          photos:
              TwinPhotos(images: images, latestCheckImages: latestCheckImages),
        );

  Cattle.fromCore(
      {required this.id,
      required this.core,
      this.modules = const TwinModules()});
  final String id;
  final SharedTwinCore core;
  final TwinModules modules;
  String get nameOrId => core.identity.name;
  String get gender => core.identity.gender;
  int get ageMonths => core.identity.ageMonths;
  String get notes => core.identity.notes;
  ProductionCategory? get productionCategory =>
      core.identity.productionCategory;
  CattleStatus get status => core.lifecycle.status;
  bool get isActive => status == CattleStatus.active;
  List<SelectedImage> get images => core.photos.images;
  List<SelectedImage> get latestCheckImages => core.photos.latestCheckImages;
  double? get estimatedWeight => core.weight.estimatedKg;
  double? get predictionSpread => core.weight.predictionSpread;
  int get validImages => core.weight.validImages;
  int get rejectedImages => core.weight.rejectedImages;
  List<WeightRecord> get history => core.weight.history;

  Cattle copyWith({
    String? id,
    ProductionCategory? productionCategory,
    AgeEvidence? ageEvidence,
    SharedTwinCore? core,
    TwinModules? modules,
    String? nameOrId,
    String? gender,
    int? ageMonths,
    String? notes,
    List<SelectedImage>? images,
    List<SelectedImage>? latestCheckImages,
    double? estimatedWeight,
    double? predictionSpread,
    bool clearPrediction = false,
    int? validImages,
    int? rejectedImages,
    List<WeightRecord>? history,
  }) {
    final current = core ?? this.core;
    return Cattle.fromCore(
      id: id ?? this.id,
      modules: modules ?? this.modules,
      core: current.copyWith(
        identity: TwinIdentity(
          name: nameOrId ?? current.identity.name,
          gender: gender ?? current.identity.gender,
          ageMonths: ageMonths ?? current.identity.ageMonths,
          notes: notes ?? current.identity.notes,
          productionCategory:
              productionCategory ?? current.identity.productionCategory,
          ageEvidence: ageEvidence ??
              (ageMonths != null && ageMonths != current.identity.ageMonths
                  ? const AgeEvidence()
                  : current.identity.ageEvidence),
        ),
        weight: TwinWeight(
          estimatedKg: estimatedWeight ?? current.weight.estimatedKg,
          predictionSpread: clearPrediction
              ? null
              : predictionSpread ?? current.weight.predictionSpread,
          validImages: validImages ?? current.weight.validImages,
          rejectedImages: rejectedImages ?? current.weight.rejectedImages,
          history: history ?? current.weight.history,
        ),
        photos: TwinPhotos(
          images: images ?? current.photos.images,
          latestCheckImages:
              latestCheckImages ?? current.photos.latestCheckImages,
          history: current.photos.history,
        ),
      ),
    );
  }
}
