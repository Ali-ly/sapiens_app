import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sapita_app/data/farm_backup_codec.dart';
import 'package:sapita_app/data/farm_identity.dart';
import 'package:sapita_app/models/cattle.dart';
import 'package:sapita_app/models/farm_snapshot.dart';
import 'package:sapita_app/models/group_record.dart';
import 'package:sapita_app/models/persisted_time.dart';
import 'package:sapita_app/state/farm_store.dart';

import 'helpers/legacy_feed_plan_fixture.dart';
import 'helpers/migration_fixtures.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(migrationFixtures[name]!) as Map<String, dynamic>;
Map<String, dynamic> payload(Map<String, dynamic> j) =>
    j['data'] as Map<String, dynamic>;
Map<String, dynamic> animal(Map<String, dynamic> j) =>
    (payload(j)['cattle'] as List).single as Map<String, dynamic>;

void main() {
  for (final version in ['unversioned', '2', '3', '4']) {
    test(
        '$version migrates deterministically to schema 5 and remains idempotent',
        () {
      final raw = migrationFixtures[version]!;
      final a = FarmBackupCodec.decode(raw, migratedAt: DateTime.utc(2000));
      final b = FarmBackupCodec.decode(raw, migratedAt: DateTime.utc(2099));
      final encoded = FarmBackupCodec.encode(a);
      expect(encoded['schemaVersion'], 5);
      expect(encoded['minimumReaderVersion'], 5);
      expect(encoded.containsKey('cattle'), isFalse);
      expect(encoded, FarmBackupCodec.encode(b));
      expect(encoded,
          FarmBackupCodec.encode(FarmBackupCodec.decode(jsonEncode(encoded))));
      expect(a.productionSystems, isNull);
      expect(a.cattle.single.productionCategory, isNull);
      expect(a.farmId, startsWith('farm-legacy-'));
      expect(a.farmIdentityOrigin, FarmIdentityOrigin.legacyDerived);
      expect(a.cattle.single.history.map((r) => r.weightKg), [300, 350]);
      expect(a.cattle.single.history.map((r) => r.dateText),
          ['2020-01-01T12:34:56', '2020-01-01T12:34:56']);
      expect(a.cattle.single.history.first.timestampBasis,
          TimestampBasis.legacyLocalUnknown);
      expect(a.cattle.single.history.map((r) => r.id).toSet(), hasLength(2));
      expect(a.cattle.single.images.map((i) => i.id).toSet(), hasLength(2));
      expect(a.cattle.single.images[0].bytes, a.cattle.single.images[1].bytes);
      expect(a.cattle.single.core.identity.ageEvidence.certainty,
          AgeCertainty.estimated);
      expect(a.cattle.single.core.identity.ageEvidence.birthDate, isNull);
      expect(a.cattle.single.ageMonths, 18);
      if (version != '4') {
        expect(a.cattle.single.core.timeline, isEmpty);
        expect(a.cattle.single.core.photos.history, isEmpty);
        expect(a.cattle.single.core.lifecycle.statuses, isEmpty);
        expect(a.cattle.single.core.health, isEmpty);
      }
      final mapped = legacyFeedPlan(
          cattle: a.cattle.single, createdAt: DateTime.utc(2026, 10, 26));
      expect(
          mapped.toJson()['weightDate'], a.cattle.single.history.last.dateText);
      final original = fixture(version);
      expect(payload(encoded)['feedPlans'], original['feedPlans']);
      final oldImages = (original['cattle'] as List).single['images'] as List;
      final newImages = animal(encoded)['images'] as List;
      for (var i = 0; i < oldImages.length; i++) {
        expect(newImages[i]['bytes'], oldImages[i]['bytes']);
        expect(newImages[i]['name'], oldImages[i]['name']);
      }
    });

    test(
        '$version load publishes only after upgrade write and does not rewrite on second load',
        () async {
      var disk = migrationFixtures[version]!;
      var writes = 0;
      late final FarmStore store;
      store = FarmStore(
          read: () async => disk,
          write: (raw) async {
            expect(store.farmId, isEmpty);
            writes++;
            disk = raw;
          });
      addTearDown(store.dispose);
      final observed = <String>[];
      store.addListener(() {
        if (store.error == null && store.ready) observed.add(store.farmId);
      });
      await store.load();
      expect(store.error, isNull);
      expect(writes, 1);
      expect(jsonDecode(disk)['schemaVersion'], 5);
      final id = store.farmId;
      expect(observed, [id]);
      await store.load();
      expect(writes, 1);
      expect(store.farmId, id);
      final restored = FarmStore(read: () async => null, write: (_) async {});
      addTearDown(restored.dispose);
      await restored.load();
      await restored.restoreBackup(jsonEncode(store.exportData()));
      expect(restored.farmId, id);
      expect(restored.allCattle.single.history.map((r) => r.id),
          store.allCattle.single.history.map((r) => r.id));
      expect(restored.allCattle.single.images.map((i) => i.id),
          store.allCattle.single.images.map((i) => i.id));
    });
  }

  test(
      'Schema 4 matches reviewed schema 5 golden, preserving references, plans and real history',
      () {
    final encoded =
        FarmBackupCodec.encode(FarmBackupCodec.decode(migrationFixtures['4']!));
    expect(encoded, fixture('5-dairy'));
    final c = FarmBackupCodec.decode(jsonEncode(encoded)).cattle.single;
    expect(c.history.first.id, 'weight-existing');
    expect(c.status, CattleStatus.sold);
    expect(c.core.timeline.map((e) => e.id), [
      'event-weight-existing',
      'event-photo-existing',
      'event-health-existing',
      'event-status-existing'
    ]);
    expect(c.core.photos.history.single.mediaId, c.images.first.id);
    expect(c.core.photos.history.single.weightRecordId, 'weight-existing');
    expect(c.core.photos.history.single.recordedAtText, '2020-01-01T12:34:56');
    expect(c.modules.beef, isNotNull);
    expect(c.modules.dairy, isNotNull);
    expect(payload(encoded)['groupFeedPlans'], fixture('4')['groupFeedPlans']);
    expect(payload(encoded)['legacyMemberships'],
        fixture('4')['legacyMemberships']);
  });

  test(
      'Schema 3 projection has a deterministic honest time anchor, not a load-time event',
      () {
    final a = FarmBackupCodec.decode(migrationFixtures['3']!,
        migratedAt: DateTime.utc(2001));
    final b = FarmBackupCodec.decode(migrationFixtures['3']!,
        migratedAt: DateTime.utc(2099));
    expect(a.groups.single.toJson(), b.groups.single.toJson());
    final record = a.groups.single.current;
    expect(record.source, 'migration');
    expect(record.timeBasis, GroupRecordTimeBasis.legacyAnchor);
    expect(record.recordedAtText, '2019-01-01T09:00:00');
    expect(record.headCount, 1);
    expect(record.averageWeightKg, 350);
    expect(a.cattle.single.core.timeline, isEmpty);
  });

  test(
      'Backfill reserves existing IDs and resolves a crafted slot collision deterministically',
      () {
    final j = fixture('2');
    final initial = FarmBackupCodec.decode(jsonEncode(j));
    final candidate = initial.cattle.single.history[1].id!;
    ((j['cattle'] as List).single['history'] as List).first['id'] = candidate;
    j['foundation'] = {'version': 1};
    final a = FarmBackupCodec.decode(jsonEncode(j)),
        b = FarmBackupCodec.decode(jsonEncode(j));
    expect(a.cattle.single.history.first.id, candidate);
    expect(a.cattle.single.history.last.id, '$candidate-1');
    expect(a.cattle.single.history.map((r) => r.id),
        b.cattle.single.history.map((r) => r.id));
  });

  test(
      'Local new-farm nonce is independent of names, retained after save/reload/restore',
      () async {
    String? disk;
    final a = FarmStore(read: () async => disk, write: (r) async => disk = r);
    final b = FarmStore(read: () async => null, write: (_) async {});
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.load();
    await b.load();
    expect(a.farmId, isNot(b.farmId));
    expect(a.farmId, startsWith('farm-local-'));
    final id = a.farmId;
    await a.load();
    expect(a.farmId, id);
    await a.settings('Another name', 'Renamed farm', 7);
    await a.load();
    expect(a.farmId, id);
    await b.restoreBackup(jsonEncode(a.exportData()));
    expect(b.farmId, id);
  });

  test(
      'Legacy ID derivation ignores key order, export timestamp and history updates',
      () {
    final a = fixture('2'), b = fixture('2');
    b['exportedAt'] = '2099-01-01T00:00:00Z';
    ((b['cattle'] as List).single['history'] as List).first['weight'] = 310;
    final ca = FarmBackupCodec.decode(jsonEncode(a)),
        cb = FarmBackupCodec.decode(jsonEncode(b));
    expect(ca.farmId, cb.farmId);
    expect(ca.cattle.single.history.map((r) => r.id),
        cb.cattle.single.history.map((r) => r.id));
    expect(ca.farmId, FarmIdentity.fromLegacy(ca));
  });

  for (final certainty in AgeCertainty.values) {
    test('Age ${certainty.name} round-trips without inferring a birthday', () {
      final j = fixture('5');
      final evidence = (animal(j)['foundation'] as Map)['ageEvidence'] as Map;
      evidence['certainty'] = certainty.name;
      if (certainty == AgeCertainty.exact) {
        evidence['birthDate'] = '2018-07-15';
      }
      final c = FarmBackupCodec.decode(jsonEncode(j)).cattle.single;
      expect(c.core.identity.ageEvidence.certainty, certainty);
      expect(c.core.identity.ageEvidence.birthDate,
          certainty == AgeCertainty.exact ? '2018-07-15' : null);
      expect(
          animal(FarmBackupCodec.encode(FarmBackupCodec.decode(jsonEncode(j))))[
              'age'],
          18);
    });
  }

  final corrupt = <String, void Function(Map<String, dynamic>)>{
    'newer root': (j) => j['schemaVersion'] = 6,
    'newer reader': (j) => j['minimumReaderVersion'] = 6,
    'newer root foundation': (j) =>
        (payload(j)['foundation'] as Map)['version'] = 999,
    'newer cattle foundation': (j) =>
        (animal(j)['foundation'] as Map)['version'] = 3,
    'newer beef namespace': (j) => (((animal(j)['foundation'] as Map)['modules']
        as Map)['beef'] as Map)['version'] = 999,
    'newer dairy namespace': (j) =>
        (((animal(j)['foundation'] as Map)['modules'] as Map)['dairy']
            as Map)['version'] = 999,
    'unknown data field': (j) => payload(j)['futureData'] = [],
    'missing feed history': (j) => payload(j).remove('feedPlans'),
    'invalid timestamp offset': (j) => ((animal(j)['history'] as List).first
        as Map)['date'] = '2020-01-01T12:34:56+25:90',
    'invalid timestamp calendar': (j) => ((animal(j)['history'] as List).first
        as Map)['date'] = '2020-02-31T12:34:56',
    'missing farmId': (j) => payload(j).remove('farmId'),
    'missing age certainty': (j) =>
        (animal(j)['foundation'] as Map).remove('ageEvidence'),
    'missing stable weight id': (j) =>
        ((animal(j)['history'] as List).last as Map).remove('id'),
    'missing stable media id': (j) =>
        ((animal(j)['images'] as List).last as Map).remove('id'),
    'duplicate stable media id': (j) => ((animal(j)['images'] as List).last
        as Map)['id'] = (animal(j)['images'] as List).first['id'],
    'wrong media reference': (j) =>
        (((animal(j)['foundation'] as Map)['photos'] as List).single
            as Map)['mediaId'] = 'missing',
    'exact age without DOB': (j) =>
        ((animal(j)['foundation'] as Map)['ageEvidence'] as Map)['certainty'] =
            'exact',
    'unknown age with DOB': (j) =>
        ((animal(j)['foundation'] as Map)['ageEvidence'] as Map)
            .addAll(<String, dynamic>{
          'certainty': 'unknown',
          'birthDate': '2018-07-15'
        }),
    'invalid DOB': (j) =>
        ((animal(j)['foundation'] as Map)['ageEvidence'] as Map).addAll(
            <String, dynamic>{'certainty': 'exact', 'birthDate': '2018-02-31'}),
  };
  for (final entry in corrupt.entries) {
    test(
        '${entry.key} rejects without writing/replacing valid state or allowing later writes',
        () async {
      var disk = migrationFixtures['5-dairy']!;
      var writes = 0;
      final store = FarmStore(
          read: () async => disk,
          write: (r) async {
            writes++;
            disk = r;
          });
      addTearDown(store.dispose);
      await store.load();
      final id = store.farmId;
      final data = fixture('5');
      entry.value(data);
      disk = jsonEncode(data);
      final before = disk;
      await store.load();
      expect(store.error, isNotNull);
      expect(store.farmId, id);
      expect(store.allCattle.single.history, hasLength(2));
      expect(writes, 0);
      expect(disk, before);
      await expectLater(store.settings('Name', 'Farm', 7), throwsStateError);
      expect(writes, 0);
      await expectLater(store.restoreBackup(before), throwsFormatException);
      expect(disk, before);
    });
  }

  test(
      'Failed migration write keeps disk, published state and notification consistent, retry succeeds',
      () async {
    var disk = migrationFixtures['5-dairy']!, fail = false, writes = 0;
    final store = FarmStore(
        read: () async => disk,
        write: (r) async {
          if (fail) throw StateError('quota');
          writes++;
          disk = r;
        });
    addTearDown(store.dispose);
    await store.load();
    final beforeId = store.farmId, beforeCow = store.allCattle.single;
    disk = migrationFixtures['2']!;
    fail = true;
    await store.load();
    expect(store.error, isNotNull);
    expect(store.farmId, beforeId);
    expect(identical(store.allCattle.single, beforeCow), isTrue);
    expect(disk, migrationFixtures['2']);
    expect(writes, 0);
    fail = false;
    await store.load();
    expect(store.error, isNull);
    expect(writes, 1);
    expect(jsonDecode(disk)['schemaVersion'], 5);
  });

  test(
      'Failed restore migration write keeps current disk and state, successful retry preserves source ID',
      () async {
    var disk = migrationFixtures['5-dairy']!, fail = false;
    final store = FarmStore(
        read: () async => disk,
        write: (r) async {
          if (fail) throw StateError('disk full');
          disk = r;
        });
    addTearDown(store.dispose);
    await store.load();
    final beforeDisk = disk, beforeId = store.farmId;
    fail = true;
    await expectLater(
        store.restoreBackup(migrationFixtures['2']!), throwsStateError);
    expect(disk, beforeDisk);
    expect(store.farmId, beforeId);
    fail = false;
    await store.restoreBackup(migrationFixtures['2']!);
    expect(
        store.farmId, FarmBackupCodec.decode(migrationFixtures['2']!).farmId);
    expect(jsonDecode(disk)['schemaVersion'], 5);
  });
  test(
      'Initial empty farm is durable; failed initial write cannot export a fake backup',
      () async {
    final store = FarmStore(
        read: () async => null, write: (_) async => throw StateError('quota'));
    addTearDown(store.dispose);
    await store.load();
    expect(store.error, isNotNull);
    expect(store.farmId, isEmpty);
    expect(store.exportData, throwsStateError);
    await expectLater(store.settings('Name', 'Farm', 7), throwsStateError);
  });
  for (final issue in [
    'invalidWeight',
    'duplicateExistingId',
    'brokenMembership',
    'newerLegacyReader',
    'unknownLegacyRoot',
    'unknownLegacyRecord',
    'unknownLegacyPlan',
    'schema4MembershipAlias',
    'schema3LegacyAlias',
    'schema2GroupHistory',
    'schema2GroupPlanHistory',
    'schema5MembershipAlias',
    'schema4FarmIdentityFields'
  ]) {
    test(
        'Corrupt legacy $issue is not normalized into a valid-looking snapshot',
        () async {
      final sourceVersion = issue == 'schema5MembershipAlias'
          ? '5'
          : issue.startsWith('schema2')
              ? '2'
              : {'brokenMembership', 'schema3LegacyAlias'}.contains(issue)
                  ? '3'
                  : '4';
      final j = fixture(sourceVersion);
      if (issue == 'invalidWeight') {
        ((j['cattle'] as List).single['history'] as List).first['weight'] = 0;
      }
      if (issue == 'duplicateExistingId') {
        ((j['cattle'] as List).single['history'] as List).last['id'] =
            'weight-existing';
      }
      if (issue == 'brokenMembership') {
        (j['memberships'] as List).single['cattleId'] = 'missing';
      }
      if (issue == 'newerLegacyReader') {
        j['minimumReaderVersion'] = 6;
      }
      if (issue == 'unknownLegacyRoot') {
        j['futurePayload'] = {};
      }
      if (issue == 'unknownLegacyRecord') {
        ((j['cattle'] as List).single['history'] as List)
            .first['futurePayload'] = {};
      }
      if (issue == 'unknownLegacyPlan') {
        (j['feedPlans'] as List).single['futurePayload'] = {};
      }
      if (issue == 'schema4FarmIdentityFields') {
        j['farmId'] = 'new-owner-field';
        j['farmIdentityOrigin'] = 'localRandom';
      }
      if (issue == 'schema4MembershipAlias') {
        j['memberships'] = fixture('3')['memberships'];
      }
      if (issue == 'schema3LegacyAlias') {
        j['legacyMemberships'] = fixture('3')['memberships'];
      }
      if (issue == 'schema2GroupHistory') {
        j['groups'] = fixture('3')['groups'];
        j['memberships'] = fixture('3')['memberships'];
      }
      if (issue == 'schema2GroupPlanHistory') {
        j['groupFeedPlans'] = fixture('4')['groupFeedPlans'];
      }
      if (issue == 'schema5MembershipAlias') {
        payload(j)['memberships'] = fixture('3')['memberships'];
      }
      var disk = migrationFixtures['5-dairy']!, writes = 0;
      final store = FarmStore(
          read: () async => disk,
          write: (r) async {
            writes++;
            disk = r;
          });
      addTearDown(store.dispose);
      await store.load();
      final previous = store.allCattle.single;
      disk = jsonEncode(j);
      final source = disk;
      await store.load();
      expect(store.error, isNotNull);
      expect(identical(store.allCattle.single, previous), isTrue);
      expect(writes, 0);
      expect(disk, source);
    });
  }
}
