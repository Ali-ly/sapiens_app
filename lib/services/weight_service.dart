import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/selected_image.dart';
import '../models/weight_estimate.dart';
import 'api_response.dart';

class WeightService {
  static Future<WeightEstimate> predictWeight(List<SelectedImage> images,
      {http.Client? client}) async {
    if (images.isEmpty || images.length > 4) {
      throw const FormatException('Pilih 1–4 foto sapi.');
    }
    final connection = client ?? http.Client();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${ApiConstants.baseUrl.replaceFirst(RegExp(r'/+$'), '')}/v2/weight'),
      );
      request.headers.addAll(
        {'Accept': 'application/json', 'ngrok-skip-browser-warning': 'true'},
      );
      for (final image in images) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            image.bytes,
            filename: image.name,
          ),
        );
      }
      final streamed =
          await connection.send(request).timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 30));
      final data = ApiResponse.decode(
        response,
        invalidResponseMessage:
            'Hasil layanan estimasi tidak dapat dibaca. Coba lagi beberapa saat.',
        rejectedResponseMessage:
            'Foto belum dapat dianalisis. Coba foto yang lebih jelas.',
      );
      return WeightEstimate.fromJson(data, imageCount: images.length);
    } on TimeoutException {
      throw const ApiException(
        'Estimasi terlalu lama. Coba lagi dengan koneksi yang stabil.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Tidak dapat menghubungi layanan estimasi. Periksa koneksi lalu coba lagi.',
      );
    } finally {
      if (client == null) {
        connection.close();
      }
    }
  }
}
