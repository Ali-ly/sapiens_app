import 'dart:convert';

Map<String, dynamic> backupPayload(Map<String, dynamic> json) =>
    json['data'] is Map ? json['data'] as Map<String, dynamic> : json;

/// Test-only legacy shape. There is deliberately no downgrade exporter in app code.
Map<String, dynamic> legacySchema4(Map<String, dynamic> json) {
  final data = Map<String, dynamic>.from(
      backupPayload(jsonDecode(jsonEncode(json)) as Map<String, dynamic>));
  data.remove('farmId');
  data.remove('farmIdentityOrigin');
  data['schemaVersion'] = 4;
  final foundation = data['foundation'] as Map;
  if ((foundation['feedStock'] as List? ?? []).isNotEmpty) {
    throw StateError('Legacy fixture cannot discard stock history.');
  }
  foundation.remove('feedStock');
  foundation['version'] = 1;
  for (final c in data['cattle'] as List) {
    final f = c['foundation'] as Map;
    f['version'] = 1;
    f.remove('ageEvidence');
    final dairy = (f['modules'] as Map)['dairy'] as Map?;
    if (dairy != null) {
      if ((dairy['records'] as List? ?? []).isNotEmpty ||
          (dairy['milk'] as List? ?? []).isNotEmpty) {
        throw StateError('Legacy fixture cannot discard Dairy history.');
      }
      dairy.remove('records');
      dairy.remove('milk');
      dairy['version'] = 1;
    }
    final beef = (f['modules'] as Map)['beef'] as Map?;
    if (beef != null) {
      if ((beef['records'] as List? ?? []).isNotEmpty) {
        throw StateError('Legacy fixture cannot discard Beef history.');
      }
      beef.remove('records');
      beef['version'] = 1;
    }
    for (final photo in f['photos'] as List) {
      (photo as Map).remove('mediaId');
    }
    for (final image in c['images'] as List) {
      (image as Map).remove('id');
    }
  }
  return data;
}
