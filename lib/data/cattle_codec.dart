import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../models/cattle.dart';
import '../models/persisted_time.dart';
import '../models/selected_image.dart';
import 'twin_codec.dart';

/// Legacy gallery/weight field locations retained inside the schema-5 payload.
class CattleCodec {
  static Map<String, dynamic> encode(Cattle c) => {
        'id': c.id,
        'name': c.nameOrId,
        'gender': c.gender,
        'age': c.ageMonths,
        'notes': c.notes,
        'weight': c.estimatedWeight,
        'spread': c.predictionSpread,
        'valid': c.validImages,
        'rejected': c.rejectedImages,
        'history': c.history
            .map(
              (r) => {
                'weight': r.weightKg,
                'date': PersistedTime.encode(r.date, r.dateText),
                'source': r.source,
                if (r.id != null) 'id': r.id
              },
            )
            .toList(),
        'foundation': TwinCodec.encode(c),
        'images': c.images
            .map((i) => {
                  'name': i.name,
                  'bytes': base64Encode(i.bytes),
                  if (i.id != null) 'id': i.id
                })
            .toList(),
      };
  static Cattle decode(Map<String, dynamic> json, {int foundationVersion = 2}) {
    if (foundationVersion >= 2 && json['foundation'] == null) {
      throw const FormatException('Fondasi schema 5 tidak lengkap.');
    }
    if (json.containsKey('foundation') && json['foundation'] == null) {
      throw const FormatException('Blok fondasi Twin tidak valid.');
    }
    return TwinCodec.decode(
        Cattle(
          id: json['id'] as String,
          nameOrId: json['name'] as String,
          gender: json['gender'] as String,
          ageMonths: json['age'] as int,
          notes: json['notes'] as String? ?? '',
          estimatedWeight: (json['weight'] as num?)?.toDouble(),
          predictionSpread: (json['spread'] as num?)?.toDouble(),
          validImages: json['valid'] as int? ?? 0,
          rejectedImages: json['rejected'] as int? ?? 0,
          history: (json['history'] as List).map(
            (value) {
              final record = Map<String, dynamic>.from(value as Map);
              return WeightRecord(
                id: record['id'] as String?,
                weightKg: (record['weight'] as num).toDouble(),
                date: PersistedTime.parse(record['date'] as String),
                dateText: record['date'] as String,
                source: record['source'] as String? ?? 'unknown',
              );
            },
          ).toList(),
          images: (json['images'] as List).map(
            (value) {
              final image = Map<String, dynamic>.from(value as Map);
              final bytes = base64Decode(image['bytes'] as String);
              return SelectedImage(
                id: image['id'] as String?,
                name: image['name'] as String,
                file: XFile.fromData(bytes, name: image['name'] as String),
                bytes: bytes,
              );
            },
          ).toList(),
        ),
        json['foundation'],
        expectedVersion: foundationVersion);
  }
}
