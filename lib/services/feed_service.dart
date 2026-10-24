import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/cattle.dart';
import '../models/feed_plan.dart';
import 'api_response.dart';
import 'feed_response_mapper.dart';

class FeedService {
  static Future<FeedPlan> calculatePlan(
      {required Cattle cattle,
      required String target,
      required String condition,
      required List<String> availableFeeds,
      http.Client? client}) async {
    final weight = cattle.estimatedWeight;
    if (weight == null) {
      throw const FormatException(
        'Catat bobot sapi terlebih dahulu untuk menghitung pakan.',
      );
    }
    final response = await calculateFeed(
      weight: weight,
      target: target,
      availableFeeds: availableFeeds,
      client: client,
    );
    return FeedResponseMapper.parse(
      cattle: cattle,
      target: target,
      condition: condition,
      feeds: availableFeeds,
      data: response,
    );
  }

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
