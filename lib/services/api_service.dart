import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/selected_image.dart';

class ApiService {
  static Future<Map<String, dynamic>> predictWeight(List<SelectedImage> images,
      {http.Client? client}) async {
    if (images.isEmpty || images.length > 4)
      throw const FormatException('Pilih 1–4 foto sapi.');
    final connection = client ?? http.Client();
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('${ApiConstants.baseUrl}/predict-weight'));
      request.headers.addAll(
          {'Accept': 'application/json', 'ngrok-skip-browser-warning': 'true'});
      for (final image in images) {
        request.files.add(http.MultipartFile.fromBytes('files', image.bytes,
            filename: image.file.name));
      }
      final streamed =
          await connection.send(request).timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 30));
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw const FormatException(
            'Layanan estimasi sedang tidak tersedia. Coba lagi beberapa saat.');
      }
      if (response.statusCode != 200) {
        dynamic detail = data is Map ? data['detail'] : null;
        for (var i = 0; i < 3 && detail is Map; i++) {
          detail = detail['message'] ?? detail['detail'];
        }
        throw Exception(detail is String
            ? detail
            : 'Foto belum dapat dianalisis. Coba foto yang lebih jelas.');
      }
      if (data is! Map<String, dynamic>)
        throw const FormatException('Hasil estimasi tidak dapat dibaca.');
      final w = data['estimated_weight_kg'];
      if (w is! num || !w.isFinite || w < 1 || w > 2000)
        throw const FormatException(
            'Layanan belum menghasilkan bobot yang valid. Coba foto lain.');
      final spread = data['prediction_spread_kg'];
      if (spread != null && (spread is! num || !spread.isFinite || spread < 0))
        throw const FormatException(
            'Variasi prediksi dari layanan tidak valid.');
      return data;
    } on TimeoutException {
      throw Exception(
          'Estimasi terlalu lama. Coba lagi dengan koneksi yang stabil.');
    } on http.ClientException {
      throw Exception(
          'Tidak dapat menghubungi layanan estimasi. Periksa koneksi lalu coba lagi.');
    } finally {
      if (client == null) connection.close();
    }
  }
}
