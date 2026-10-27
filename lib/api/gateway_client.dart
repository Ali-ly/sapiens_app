import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/value.dart';
import 'contracts.dart';

class GatewayClient implements Gateway {
  GatewayClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ??
                const String.fromEnvironment('API_BASE_URL',
                    defaultValue:
                        'https://almighty-haphazard-pawing.ngrok-free.dev'))
            .replaceFirst(RegExp(r'/+$'), '');
  final http.Client _client;
  final String baseUrl;
  static const headers = {
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true'
  };
  void close() => _client.close();
  Json decode(http.Response response) {
    Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw GatewayError(
          response.statusCode >= 400
              ? 'Gateway tidak tersedia (HTTP ${response.statusCode}). Periksa koneksi atau coba lagi.'
              : 'Respons layanan tidak dapat dibaca. Tidak ada data yang disimpan.',
          statusCode: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Object? detail = parsed is Map ? parsed['detail'] : null;
      for (var i = 0; i < 4 && detail is Map; i++) {
        detail = detail['message'] ?? detail['detail'];
      }
      throw GatewayError(
          detail is String
              ? readable(detail)
              : 'Layanan menolak data (HTTP ${response.statusCode}). Tinjau data sapi dan bahan.',
          statusCode: response.statusCode,
          details: parsed);
    }
    return object(parsed);
  }

  String readable(String message) {
    const labels = {
      'unsupported_range': 'Di luar jangkauan layanan',
      'body_weight_kg': 'bobot sapi',
      'target_adg_kg_day': 'target kenaikan berat per hari',
      'dairy_stage': 'fase fisiologis',
      'milk_kg_day': 'berat susu per hari',
      'parity_group': 'kelompok paritas',
      'ration_ndf_pct_dm': 'NDF ransum',
      'weeks_to_calving': 'minggu menuju kelahiran'
    };
    var result = message;
    for (final e in labels.entries) {
      result = result.replaceAll(e.key, e.value);
    }
    return result;
  }

  Future<T> network<T>(Future<T> Function() send) async {
    try {
      return await send().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const GatewayError(
          'Layanan terlalu lama merespons. Data lokal tetap tersimpan; coba lagi.');
    } on http.ClientException {
      throw const GatewayError(
          'Tidak dapat terhubung ke Gateway. Periksa koneksi dan alamat backend.');
    }
  }

  @override
  Future<Json> health() => network(() async => decode(
      await _client.get(Uri.parse('$baseUrl/health'), headers: headers)));
  @override
  Future<List<FeedIngredient>> feeds(FarmMode mode) => network(() async {
        final j = decode(await _client.get(
            Uri.parse('$baseUrl/v2/feeds/${mode.name}'),
            headers: headers));
        require(j['production_category'] == mode.name && j['feeds'] is List,
            'Kategori katalog tidak sesuai akun.');
        final result = (j['feeds'] as List)
            .map((e) => FeedIngredient.fromJson(object(e)))
            .where((f) => f.validFor.contains(mode))
            .toList();
        require(result.map((f) => f.id).toSet().length == result.length,
            'Katalog berisi ID bahan duplikat.');
        return List.unmodifiable(result);
      });
  @override
  Future<Json> nutrition(Json request) => network(() async {
        final result = decode(await _client.post(
            Uri.parse('$baseUrl/v2/nutrition'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(request)));
        require(
            result['production_category'] == null ||
                result['production_category'] == request['production_category'],
            'Kategori hasil nutrisi tidak sesuai akun.');
        return result;
      });
  @override
  Future<WeightEstimate> weight(List<UploadPhoto> photos) => network(() async {
        require(photos.isNotEmpty && photos.length <= 4, 'Pilih 1–4 foto.');
        require(photos.map((p) => p.name).toSet().length == photos.length,
            'Nama unggahan foto harus unik.');
        require(
            photos.every(
                (p) => p.bytes.isNotEmpty && p.bytes.length <= 8 * 1024 * 1024),
            'Setiap foto harus berisi data dan maksimal 8 MB.');
        final request =
            http.MultipartRequest('POST', Uri.parse('$baseUrl/v2/weight'))
              ..headers.addAll(headers);
        for (final p in photos) {
          request.files.add(
              http.MultipartFile.fromBytes('files', p.bytes, filename: p.name));
        }
        final response =
            await http.Response.fromStream(await _client.send(request));
        return WeightEstimate.parse(decode(response), photos);
      });
}
