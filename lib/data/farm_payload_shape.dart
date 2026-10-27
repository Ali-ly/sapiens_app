import 'twin_codec.dart';

/// Reject unrecognized persisted fields rather than discarding potential data
/// during an upgrade. Optional historical fields stay optional in the decoder.
class FarmPayloadShape {
  static void validate(Map<String, dynamic> j, int version) {
    TwinCodec.fields(j, {
      if (version < 5) ...{
        'schemaVersion',
        'minimumReaderVersion',
        'exportedAt'
      },
      'farmer',
      'farm',
      'reminderDays',
      'demo',
      'cattle',
      'feedPlans',
      'foundation',
      if (version >= 5) ...{'farmId', 'farmIdentityOrigin'},
      if (version == 3) ...{'groups', 'memberships'},
      if (version >= 4) ...{'groups', 'groupFeedPlans', 'legacyMemberships'},
    });
    void rows(Object? raw, void Function(Map<String, dynamic>) visit) {
      if (raw == null) return;
      for (final value in raw as List) {
        visit(Map<String, dynamic>.from(value as Map));
      }
    }

    void portions(Map<String, dynamic> p) => rows(p['portions'],
        (r) => TwinCodec.fields(r, {'key', 'asFedKg', 'dryMatterKg', 'ratio'}));
    rows(j['cattle'], (c) {
      TwinCodec.fields(c, {
        'id',
        'name',
        'gender',
        'age',
        'notes',
        'weight',
        'spread',
        'valid',
        'rejected',
        'history',
        'images',
        'foundation'
      });
      rows(c['history'],
          (r) => TwinCodec.fields(r, {'id', 'weight', 'date', 'source'}));
      rows(c['images'], (r) => TwinCodec.fields(r, {'id', 'name', 'bytes'}));
    });
    rows(j['feedPlans'], (p) {
      TwinCodec.fields(p, {
        'id',
        'cattleId',
        'cattleName',
        'beefContext',
        'nutritionSnapshot',
        'nutritionRequest',
        'planType',
        'weightKg',
        'ageMonths',
        'gender',
        'bodyCondition',
        'target',
        'availableFeeds',
        'createdAt',
        'weightDate',
        'portions',
        'totalDryMatterKg',
        'warning',
        'notes'
      });
      portions(p);
    });
    rows(j['groups'], (g) {
      if (version < 4) {
        TwinCodec.fields(g, {'id', 'name', 'notes', 'createdAt', 'archivedAt'});
      } else {
        TwinCodec.fields(g, {'id', 'createdAt', 'history'});
        rows(
            g['history'],
            (r) => TwinCodec.fields(r, {
                  'id',
                  'recordedAt',
                  'name',
                  'headCount',
                  'averageWeightKg',
                  'target',
                  'notes',
                  'archivedAt',
                  'source',
                  'timeBasis'
                }));
      }
    });
    rows(j['groupFeedPlans'], (p) {
      TwinCodec.fields(p, {
        'id',
        'groupId',
        'inputRevision',
        'headCount',
        'averageWeightKg',
        'target',
        'createdAt',
        'availableFeeds',
        'portions',
        'totalDryMatterKg',
        'warning',
        'notes'
      });
      portions(p);
    });
    for (final key in ['memberships', 'legacyMemberships']) {
      rows(
          j[key],
          (m) => TwinCodec.fields(
              m, {'id', 'cattleId', 'groupId', 'joinedAt', 'leftAt'}));
    }
  }
}
