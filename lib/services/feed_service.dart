import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/feed_api_v2.dart';
import '../models/production.dart';
import 'api_response.dart';

class FeedService {
  /// v2 catalog: stable backend feed IDs, independent of legacy UI labels.
  static Future<FeedCatalogResponse> fetchFeeds({
    required ProductionCategory productionCategory,
    http.Client? client,
  }) async {
    final data =
        await _v2('/v2/feeds/${productionCategory.name}', client: client);
    final catalog = FeedCatalogResponse.fromJson(data);
    if (catalog.productionCategory != productionCategory) {
      throw const FormatException('Kategori katalog tidak sesuai permintaan.');
    }
    return catalog;
  }

  /// Evaluates user-supplied quantities; does not create a FeedPlan/ration.
  static Future<NutritionResponse> calculateNutrition({
    required NutritionRequest request,
    http.Client? client,
  }) async {
    final data =
        await _v2('/v2/nutrition', body: request.toJson(), client: client);
    final result = NutritionResponse.fromJson(data);
    if (result.productionCategory != null &&
        result.productionCategory != request.productionCategory) {
      throw const FormatException('Kategori hasil nutrisi tidak sesuai input.');
    }
    return result;
  }

  static Future<Map<String, dynamic>> _v2(String path,
      {Map<String, dynamic>? body, http.Client? client}) async {
    final connection = client ?? http.Client();
    final base = ApiConstants.baseUrl.replaceFirst(RegExp(r'/+$'), '');
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    try {
      final uri = Uri.parse('$base$path');
      final response = await (body == null
              ? connection.get(uri, headers: headers)
              : connection.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(const Duration(seconds: 30));
      return ApiResponse.decode(response,
          invalidResponseMessage: 'Respons API pakan v2 tidak dapat dibaca.',
          rejectedResponseMessage: 'Permintaan API pakan v2 ditolak.');
    } on TimeoutException {
      throw const ApiException('Layanan pakan v2 terlalu lama merespons.');
    } on http.ClientException {
      throw const ApiException('Tidak dapat menghubungi layanan pakan v2.');
    } finally {
      if (client == null) connection.close();
    }
  }

  /// Compatibility transport still required by GroupFeedService.
  /// Individual evaluations use calculateNutrition; never route them here.
  static Future<Map<String, dynamic>> calculateFeed(
      {required double weight,
      required String target,
      required List<String> availableFeeds,
      http.Client? client}) async {
    if (!weight.isFinite || weight <= 0 || availableFeeds.isEmpty) {
      throw const FormatException('Pilih bobot dan minimal satu bahan pakan.');
    }
    final connection = client ?? http.Client();
    try {
      final response = await connection
          .post(
            Uri.parse('${ApiConstants.baseUrl}/calculate-feed'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true'
            },
            body: jsonEncode(
              {
                'weight': weight,
                'target': target,
                'available_feeds': availableFeeds
              },
            ),
          )
          .timeout(const Duration(seconds: 30));
      return ApiResponse.decode(
        response,
        invalidResponseMessage:
            'Hasil layanan pakan tidak dapat dibaca. Coba lagi beberapa saat.',
        rejectedResponseMessage:
            'Perhitungan belum berhasil. Silakan coba lagi.',
      );
    } on TimeoutException {
      throw const ApiException(
        'Perhitungan terlalu lama. Periksa koneksi lalu coba lagi.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Tidak dapat menghubungi layanan pakan. Periksa koneksi dan coba lagi.',
      );
    } finally {
      if (client == null) {
        connection.close();
      }
    }
  }
}
