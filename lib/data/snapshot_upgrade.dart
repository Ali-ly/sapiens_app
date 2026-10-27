import '../models/beef/beef_rules.dart';
import '../models/cattle.dart';
import '../models/dairy/dairy_rules.dart';
import '../models/farm_snapshot.dart';
import '../models/feed_plan_rules.dart';
import '../models/group_rules.dart';
import '../models/twin_rules.dart';
import 'farm_identity.dart';

/// Pure normalization. No clocks, random values, synthetic events or disk I/O.
class SnapshotUpgrade {
  static FarmSnapshot complete(FarmSnapshot input) {
    TwinRules.validate(input);
    BeefRules.validate(input);
    DairyRules.validate(input);
    GroupRules.validate(input);
    final cattleIds = input.cattle.map((c) => c.id).toSet(),
        planIds = <String>{};
    for (final plan in input.feedPlans) {
      FeedPlanRules.validate(plan);
      if (!cattleIds.contains(plan.cattleId) || !planIds.add(plan.id)) {
        throw const FormatException(
            'Referensi atau ID rencana pakan tidak valid.');
      }
    }
    final farmId =
        input.farmId.isEmpty ? FarmIdentity.fromLegacy(input) : input.farmId;
    final used = <String>{
      farmId,
      ...input.feedStock.map((e) => e.id),
      ...input.cattle.expand((c) => [
            ...?c.modules.dairy?.records.map((r) => r.id),
            ...?c.modules.dairy?.milk.map((r) => r.id)
          ]),
      ...input.cattle
          .expand((c) => c.modules.beef?.records ?? <BeefRecord>[])
          .map((r) => r.id),
      ...input.cattle.map((c) => c.id),
      ...input.groups.map((g) => g.id),
      ...input.feedPlans.map((p) => p.id),
      ...input.groupFeedPlans.map((p) => p.id),
      ...input.groups.expand((g) => g.history).map((r) => r.id),
      ...input.legacyMemberships.map((m) => m.id),
      ...input.cattle
          .expand((c) => c.history)
          .map((r) => r.id)
          .whereType<String>(),
      ...input.cattle
          .expand((c) => c.images)
          .map((i) => i.id)
          .whereType<String>(),
      ...input.cattle.expand((c) => c.core.timeline).map((r) => r.id),
      ...input.cattle.expand((c) => c.core.photos.history).map((r) => r.id),
      ...input.cattle.expand((c) => c.core.health).map((r) => r.id),
      ...input.cattle.expand((c) => c.core.lifecycle.statuses).map((r) => r.id),
      ...input.cattle.expand((c) => c.core.lifecycle.stages).map((r) => r.id),
    };
    String allocate(String kind, String cattleId, int slot) {
      final base = '$kind-backfill-${FarmIdentity.digest([
            'slot-v1',
            farmId,
            cattleId,
            slot
          ])}';
      var candidate = base, suffix = 0;
      while (!used.add(candidate)) {
        candidate = '$base-${++suffix}';
      }
      return candidate;
    }

    final animals = input.cattle.map((c) {
      final weights = List.generate(c.history.length, (i) {
        final r = c.history[i];
        return r.id != null
            ? r
            : WeightRecord(
                id: allocate('weight', c.id, i),
                weightKg: r.weightKg,
                date: r.date,
                dateText: r.dateText,
                source: r.source);
      });
      final images = List.generate(
          c.images.length,
          (i) => c.images[i].id != null
              ? c.images[i]
              : c.images[i].withId(allocate('media', c.id, i)));
      final photos = c.core.photos.history
          .map((r) =>
              r.mediaId == null ? r.withMediaId(images[r.imageIndex].id!) : r)
          .toList();
      return c.copyWith(
          history: weights,
          images: images,
          core: c.core.copyWith(
              photos: TwinPhotos(
                  images: c.images,
                  latestCheckImages: c.latestCheckImages,
                  history: photos)));
    }).toList();
    final result = input.copyWith(farmId: farmId, cattle: animals);
    TwinRules.validate(result, requireStableIdentity: true);
    return result;
  }
}
