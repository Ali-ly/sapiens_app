import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sapiens_app/api/contracts.dart';
import 'package:sapiens_app/api/gateway_client.dart';
import 'package:sapiens_app/domain/value.dart';
import 'helpers/live_fixtures.dart';

void main() {
  for (final mode in FarmMode.values) {
    test(
        'GET ${mode.name} catalog uses v2 and valid_for, retains optional provenance',
        () async {
      final client = MockClient((r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/v2/feeds/${mode.name}');
        expect(r.headers['ngrok-skip-browser-warning'], 'true');
        return http.Response(
            jsonEncode(mode == FarmMode.beef ? beefCatalog() : dairyCatalog()),
            200);
      });
      addTearDown(client.close);
      final rows =
          await GatewayClient(client: client, baseUrl: 'https://test.invalid/')
              .feeds(mode);
      expect(rows, isNotEmpty);
      expect(rows.every((r) => r.validFor.contains(mode)), isTrue);
      expect(rows.any((r) => r.productSpecific), isTrue);
      expect(rows.first.raw.containsKey('confidence_note'), isTrue);
    });
  }
  test(
      'POST nutrition preserves request and partial backend response unchanged',
      () async {
    final request = {
      'production_category': 'dairy',
      'cattle': {
        'body_weight_kg': 500,
        'dairy_stage': 'early_lactation',
        'dim': 26,
        'milk_kg_day': 15,
        'parity_group': 'primiparous',
        'milk_fat_pct': 3.8
      },
      'feed_items': [
        {'feed_id': 'rumput_gajah', 'as_fed_kg_day': 25}
      ]
    };
    final client = MockClient((r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/v2/nutrition');
      expect(jsonDecode(r.body), request);
      return http.Response(jsonEncode(dairyResponse()), 200);
    });
    addTearDown(client.close);
    final result =
        await GatewayClient(client: client, baseUrl: 'https://test.invalid')
            .nutrition(request);
    expect(result, dairyResponse());
    expect(object(object(result['adequacy'])['energy'])['status'],
        'not_fully_evaluable');
  });
  test(
      'Multipart weight uses only /v2/weight files, preserves partial rejection identity',
      () async {
    final photos = [
      UploadPhoto(name: 'valid.jpg', bytes: [1, 2, 3]),
      UploadPhoto(name: 'rejected.jpg', bytes: [4, 5, 6])
    ];
    final client = MockClient((r) async {
      expect(r.url.path, '/v2/weight');
      expect(r.method, 'POST');
      final body = latin1.decode(r.bodyBytes);
      expect(RegExp('name="files"').allMatches(body), hasLength(2));
      return http.Response(
          jsonEncode({
            'estimated_weight_kg': 301,
            'num_valid_images': 1,
            'prediction_spread_kg': 0,
            'rejected_files': ['rejected.jpg']
          }),
          200);
    });
    addTearDown(client.close);
    final result =
        await GatewayClient(client: client, baseUrl: 'https://test.invalid')
            .weight(photos);
    expect(result.kg, 301);
    expect(result.accepted.single.name, 'valid.jpg');
    expect(result.rejected, ['rejected.jpg']);
  });
  test(
      'Malformed, mismatched and all-rejected weight responses cannot create a record',
      () {
    final photos = [
      UploadPhoto(name: 'cow.jpg', bytes: [1])
    ];
    for (final j in <Json>[
      {'estimated_weight_kg': 0},
      {'estimated_weight_kg': 300, 'num_valid_images': 2, 'rejected_files': []},
      {
        'estimated_weight_kg': 300,
        'num_valid_images': 0,
        'rejected_files': ['cow.jpg']
      },
      {
        'estimated_weight_kg': 300,
        'num_valid_images': 1,
        'rejected_files': ['unknown.jpg']
      }
    ]) {
      expect(() => WeightEstimate.parse(j, photos), throwsFormatException);
    }
  });
  test(
      'Non-JSON errors preserve status; UTF-8 warnings are decoded without corruption',
      () {
    final gateway = GatewayClient();
    addTearDown(gateway.close);
    expect(
        () => gateway.decode(http.Response('<html>offline</html>', 503)),
        throwsA(
            isA<GatewayError>().having((e) => e.statusCode, 'status', 503)));
    final j = gateway.decode(http.Response.bytes(
        utf8.encode('{"warnings":["Data belum lengkap — pakan"]}'), 200));
    expect(j['warnings'], ['Data belum lengkap — pakan']);
  });
  test('Wrong catalog/evaluation category is rejected instead of relabeled',
      () async {
    final c = MockClient((r) async => http.Response(
        jsonEncode(r.method == 'GET'
            ? dairyCatalog()
            : {'production_category': 'dairy'}),
        200));
    addTearDown(c.close);
    final gateway = GatewayClient(client: c, baseUrl: 'https://test.invalid');
    await expectLater(gateway.feeds(FarmMode.beef), throwsFormatException);
    await expectLater(gateway.nutrition({'production_category': 'beef'}),
        throwsFormatException);
  });
}
