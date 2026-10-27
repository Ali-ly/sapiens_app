import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/farm_snapshot.dart';

class FarmIdentity {
  /// Local nonce, not an assertion of global identity or ownership.
  static String newLocal() {
    final random = Random.secure();
    return 'farm-local-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Equal legacy identities derive equal IDs; indistinguishable backups cannot
  /// be proven to represent different physical farms until sync reconciliation.
  static String fromLegacy(FarmSnapshot snapshot) => 'farm-legacy-${digest([
            'farm-v1',
            snapshot.farmer,
            snapshot.farm,
            snapshot.cattle.map((c) => c.id).toList()..sort(),
            snapshot.groups.map((g) => g.id).toList()..sort(),
          ])}';
  static String digest(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();
}
