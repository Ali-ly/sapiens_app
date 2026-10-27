import 'dart:convert';

import '../models/farm_snapshot.dart';
import 'cattle_codec.dart';
import 'farm_payload_codec.dart';
import 'snapshot_upgrade.dart';
import 'twin_codec.dart';

class FarmReadResult {
  const FarmReadResult(this.snapshot, this.sourceSchema,
      {this.foundationUpgrade = false});
  final bool foundationUpgrade;
  final FarmSnapshot snapshot;
  final int? sourceSchema;
  bool get needsUpgrade =>
      sourceSchema != FarmBackupCodec.schemaVersion || foundationUpgrade;
}

/// Schema 5 is an envelope, with no legacy root aliases. Historical versionless
/// readers must fail their required-field casts instead of ignoring new fields.
class FarmBackupCodec {
  static const schemaVersion = 5;
  static const format = 'sapiens.farm';
  static Map<String, dynamic> encode(FarmSnapshot snapshot,
      {DateTime? exportedAt}) {
    final value = SnapshotUpgrade.complete(snapshot);
    return {
      'format': format,
      'schemaVersion': schemaVersion,
      'minimumReaderVersion': schemaVersion,
      if (exportedAt != null)
        'exportedAt': exportedAt.toUtc().toIso8601String(),
      'data': {
        'farmId': value.farmId,
        'farmIdentityOrigin': value.farmIdentityOrigin.name,
        'foundation': {
          'version': 3,
          'feedStock': value.feedStock.map((e) => e.toJson()).toList(),
          if (value.productionSystems != null)
            'productionSystems': value.productionSystems!.name
        },
        'farmer': value.farmer,
        'farm': value.farm,
        'reminderDays': value.reminderDays,
        'demo': value.hasExamples,
        'cattle': value.cattle.map(CattleCodec.encode).toList(),
        'feedPlans': value.feedPlans.map((p) => p.toJson()).toList(),
        'groups': value.groups.map((g) => g.toJson()).toList(),
        'groupFeedPlans': value.groupFeedPlans.map((p) => p.toJson()).toList(),
        'legacyMemberships':
            value.legacyMemberships.map((m) => m.toJson()).toList(),
      },
    };
  }

  static bool _legacyDairy(Map<String, dynamic> data) =>
      (data['cattle'] as List).any((c) {
        final modules = (c['foundation'] as Map)['modules'] as Map;
        return (modules['dairy'] as Map?)?['version'] == 1;
      });

  static FarmSnapshot decode(String raw, {DateTime? migratedAt}) =>
      read(raw).snapshot;
  static FarmReadResult read(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) {
        throw const FormatException('Format cadangan tidak dikenali.');
      }
      final requiredReader = j['minimumReaderVersion'];
      if (j.containsKey('minimumReaderVersion') &&
          (requiredReader is! int ||
              requiredReader < 1 ||
              requiredReader > schemaVersion)) {
        throw const FormatException('Data membutuhkan pembaca lebih baru.');
      }
      final version = j['schemaVersion'];
      if (version != null &&
          (version is! int || !{2, 3, 4, 5}.contains(version))) {
        throw const FormatException(
            'Versi data belum didukung. Gunakan aplikasi yang sesuai.');
      }
      if (version == schemaVersion) {
        TwinCodec.fields(j, {
          'format',
          'schemaVersion',
          'minimumReaderVersion',
          'exportedAt',
          'data'
        });
        if (j['format'] != format ||
            j['minimumReaderVersion'] is! int ||
            j['minimumReaderVersion'] != schemaVersion) {
          throw const FormatException('Reader data ini belum didukung.');
        }
        if (j.containsKey('exportedAt')) {
          DateTime.parse(j['exportedAt'] as String);
        }
        final data = TwinCodec.object(j['data'], {
          'farmId',
          'farmIdentityOrigin',
          'foundation',
          'farmer',
          'farm',
          'reminderDays',
          'demo',
          'cattle',
          'feedPlans',
          'groups',
          'groupFeedPlans',
          'legacyMemberships'
        });
        if (!data.keys.toSet().containsAll({
              'farmId',
              'farmIdentityOrigin',
              'foundation',
              'farmer',
              'farm',
              'reminderDays',
              'demo',
              'cattle',
              'feedPlans',
              'groups',
              'groupFeedPlans',
              'legacyMemberships'
            }) ||
            data['feedPlans'] is! List ||
            data['demo'] is! bool) {
          throw const FormatException('Payload schema 5 tidak lengkap.');
        }
        final foundationVersion = (data['foundation'] as Map)['version'];
        if (foundationVersion != 2 && foundationVersion != 3) {
          throw const FormatException('Versi farm belum didukung.');
        }
        return FarmReadResult(
            FarmPayloadCodec.decode(data,
                schemaVersion: schemaVersion,
                foundationVersion: foundationVersion as int,
                requireIdentity: true),
            schemaVersion,
            foundationUpgrade: foundationVersion == 2 || _legacyDairy(data));
      }
      // Validate the historical representation before filling any missing IDs.
      final legacy = FarmPayloadCodec.decode(j,
          schemaVersion: version as int? ?? 2, foundationVersion: 1);
      return FarmReadResult(SnapshotUpgrade.complete(legacy), version);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'Cadangan tidak dapat dibaca. Gunakan JSON hasil ekspor SAPIENS.');
    }
  }
}
