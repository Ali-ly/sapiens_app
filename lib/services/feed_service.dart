import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class FeedService {
  static Future<Map<String, dynamic>> calculateFeed(
      {required double weight,
      required String target,
      required List<String> availableFeeds,
      http.Client? client}) async {
    if (!weight.isFinite || weight <= 0 || availableFeeds.isEmpty)
      throw const FormatException('Pilih bobot dan minimal satu bahan pakan.');
    final connection = client ?? http.Client();
    try {
      final response = await connection
          .post(Uri.parse('${ApiConstants.baseUrl}/calculate-feed'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'ngrok-skip-browser-warning': 'true'
              },
              body: jsonEncode({
                'weight': weight,
                'target': target,
                'available_feeds': availableFeeds
              }))
          .timeout(const Duration(seconds: 30));
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw const FormatException(
            'Layanan pakan sedang tidak tersedia. Coba lagi beberapa saat.');
      }
      if (response.statusCode != 200) {
        dynamic detail = data is Map ? data['detail'] : null;
        for (var i = 0; i < 3 && detail is Map; i++) {
          detail = detail['message'] ?? detail['detail'];
        }
        final message = detail is String ? detail : null;
        throw Exception(
            message ?? 'Perhitungan belum berhasil. Silakan coba lagi.');
      }
      if (data is! Map<String, dynamic>)
        throw const FormatException('Hasil layanan pakan tidak dapat dibaca.');
      return data;
    } on TimeoutException {
      throw Exception(
          'Perhitungan terlalu lama. Periksa koneksi lalu coba lagi.');
    } on http.ClientException {
      throw Exception(
          'Tidak dapat menghubungi layanan pakan. Periksa koneksi dan coba lagi.');
    } finally {
      if (client == null) connection.close();
    }
  }
}
