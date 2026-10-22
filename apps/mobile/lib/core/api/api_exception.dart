import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.details, this.reason});

  final int statusCode;
  final String message;
  final dynamic details;
  final String? reason;

  bool get isNetwork => statusCode == 0;
  bool get isAuth => statusCode == 401;
  bool get isRetryable => isNetwork || statusCode >= 500 || statusCode == 429;

  @override
  String toString() => message;
}

ApiException mapDioException(DioException error) {
  final response = error.response;
  if (response == null) {
    return ApiException(
      0,
      'Network error — check that the API is reachable.',
      details: error.message,
    );
  }
  final data = response.data;
  String message = 'Request failed';
  String? reason;
  dynamic details;
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    message = (map['error'] ?? map['message'] ?? message) as String;
    details = map['details'];
    reason = map['reason'] as String?;
  }
  return ApiException(response.statusCode ?? 0, message, details: details, reason: reason);
}
