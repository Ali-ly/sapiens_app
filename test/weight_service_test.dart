import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sapita_app/core/constants/api_constants.dart';
import 'package:sapita_app/models/selected_image.dart';
import 'package:sapita_app/services/api_response.dart';
import 'package:sapita_app/services/weight_service.dart';

SelectedImage photo(int i) {
  final bytes = Uint8List.fromList([65 + i, 66 + i, 67 + i]);
  final name = 'cow-$i.jpg';
  return SelectedImage(
      file: XFile.fromData(bytes, name: name), bytes: bytes, name: name);
}

class OwnedClient extends http.BaseClient {
  OwnedClient(this.delegate);
  final http.Client delegate;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      delegate.send(request);
  @override
  void close() {
    closed = true;
    delegate.close();
  }
}

void main() {
  for (final count in [1, 4]) {
    test(
        '$count images use shared Gateway base URL and canonical v2 alias without payload changes',
        () async {
      final images = List.generate(count, photo);
      final original =
          images.map((image) => List<int>.of(image.bytes)).toList();
      var calls = 0;
      final client = OwnedClient(MockClient((request) async {
        calls++;
        final base = ApiConstants.baseUrl.replaceFirst(RegExp(r'/+$'), '');
        expect(request.url, Uri.parse('$base/v2/weight'));
        expect(request.url.path, isNot(contains('predict-weight')));
        expect(request.method, 'POST');
        expect(request.headers['accept'], 'application/json');
        expect(request.headers['ngrok-skip-browser-warning'], 'true');
        expect(request.headers['content-type'],
            startsWith('multipart/form-data; boundary='));
        expect(
            RegExp('name="files"').allMatches(request.body), hasLength(count));
        for (var i = 0; i < count; i++) {
          expect(request.body, contains('filename="cow-$i.jpg"'));
          expect(request.body,
              contains('\r\n\r\n${String.fromCharCodes(original[i])}\r\n'));
        }
        return http.Response(
            jsonEncode({
              'estimated_weight_kg': 350.5,
              'prediction_spread_kg': 5.25,
              'num_valid_images': count == 4 ? 3 : 1,
              'rejected_files': count == 4 ? ['cow-3.jpg'] : [],
            }),
            200);
      }));
      addTearDown(client.close);
      final result = await WeightService.predictWeight(images, client: client);
      expect(calls, 1);
      expect(client.closed, isFalse);
      expect(result.weightKg, 350.5);
      expect(result.predictionSpread, 5.25);
      expect(result.validImages, count == 4 ? 3 : 1);
      expect(result.rejectedImages, count == 4 ? 1 : 0);
      for (var i = 0; i < count; i++) {
        expect(images[i].bytes, original[i]);
      }
    });
  }

  test('Invalid image count is rejected before contacting Gateway', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    for (final images in [<SelectedImage>[], List.generate(5, photo)]) {
      await expectLater(WeightService.predictWeight(images, client: client),
          throwsFormatException);
    }
    expect(calls, 0);
  });

  test(
      'Gateway rejection preserves downstream message and never retries an internal route',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.path, endsWith('/v2/weight'));
      return http.Response(
          '{"detail":{"detail":"Foto tidak dapat diproses."}}', 422);
    });
    addTearDown(client.close);
    await expectLater(
        WeightService.predictWeight([photo(0)], client: client),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having(
                (e) => e.message, 'message', 'Foto tidak dapat diproses.')));
    expect(calls, 1);
  });

  test(
      'HTML/offline Gateway and invalid legacy response do not create an estimate',
      () async {
    for (final response in [
      http.Response('<html>offline</html>', 502),
      ...[-1, 0, 2500, '350', null].map((weight) =>
          http.Response(jsonEncode({'estimated_weight_kg': weight}), 200)),
    ]) {
      final client = MockClient((_) async => response);
      addTearDown(client.close);
      await expectLater(WeightService.predictWeight([photo(0)], client: client),
          throwsFormatException);
    }
  });

  test(
      'Connection failure keeps existing user-facing error and injected client ownership',
      () async {
    final client = OwnedClient(
        MockClient((_) async => throw http.ClientException('offline')));
    addTearDown(client.close);
    await expectLater(WeightService.predictWeight([photo(0)], client: client),
        throwsA(isA<ApiException>()));
    expect(client.closed, isFalse);
  });
}
