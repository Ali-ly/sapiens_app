import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// FastAPI gateways can nest a downstream error under more than one `detail` key.
class ApiResponse {
  static Map<String, dynamic> decode(http.Response response,
      {required String invalidResponseMessage,
      required String rejectedResponseMessage}) {
    final Object? value;
    try {
      value = jsonDecode(response.body);
    } on FormatException {
      throw FormatException(invalidResponseMessage);
    }
    if (response.statusCode != 200) {
      Object? detail = value is Map ? value['detail'] : null;
      for (var depth = 0; depth < 3 && detail is Map; depth++) {
        detail = detail['message'] ?? detail['detail'];
      }
      throw ApiException(
        detail is String ? detail : rejectedResponseMessage,
        statusCode: response.statusCode,
      );
    }
    if (value is! Map<String, dynamic>) {
      throw FormatException(invalidResponseMessage);
    }
    return value;
  }
}
