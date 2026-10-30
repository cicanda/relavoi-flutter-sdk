import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../relavoi_config.dart';
import '../relavoi_exception.dart';
import '../internal/logger.dart';

class ApiClient {
  late final Dio _dio;
  final RelavoiConfig config;
  String? _token;

  ApiClient(this.config) {
    _dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401 && _token != null) {
          // Token expired, will be handled by AuthManager
          RelavoiLogger.warn('Token expired');
        }
        handler.next(error);
      },
    ));
  }

  void setToken(String token) {
    _token = token;
  }

  String? get token => _token;

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParams);
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : {'data': response.data};
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : {'data': response.data};
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path,
      {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : {'data': response.data};
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Raw POST without auth (used for initial authentication)
  Future<Map<String, dynamic>> postUnauthenticated(
      String path, Map<String, dynamic> data) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ));
      final response = await dio.post(path, data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Visible for testing: the error mapper, which is otherwise only reachable
  /// through a real HTTP failure.
  @visibleForTesting
  RelavoiException mapErrorForTest(DioException e) => _mapError(e);

  /// Map a Dio failure to a typed Relavoi exception.
  ///
  /// Only `type` and `detail` are read out of an error response. The raw body
  /// is never put into an exception message, and neither is Dio's own message.
  /// That is deliberate rather than tidy: an exception message ends up printed
  /// and in crash reporters, Dio's message embeds the request URI, and
  /// `/sessions/verify` carries a subscriber's number in its query string. So a
  /// failed verification used to write a plaintext phone number to the log.
  RelavoiException _mapError(DioException e) {
    final status = e.response?.statusCode;
    final problem = _problem(e.response?.data);
    final detail = problem?['detail'];
    final slug = problem?['slug'];

    if (status == 400 || status == 422) {
      if (slug == 'number-not-supported') {
        return NumberNotSupportedException(
            detail ?? 'That phone number is not supported.');
      }
      if (slug == 'cross-border-not-supported') {
        return CrossBorderNotSupportedException(detail ??
            'Both numbers in a session must be from the same country.');
      }
      return ValidationException(detail ?? 'Validation failed.');
    }

    switch (status) {
      case 401:
        return AuthenticationException('Authentication failed');
      case 429:
        return TierLimitException(detail ?? 'Rate limit exceeded.');
      case 503:
        return SessionException(detail ?? 'Service unavailable.',
            statusCode: 503);
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError) {
          // Describing the type rather than repeating Dio's message, which
          // carries the full request URI.
          return NetworkException('Network error (${e.type.name}).',
              originalError: e);
        }
        return RelavoiException(
            detail ?? 'API error${status == null ? '' : ' ($status)'}.',
            statusCode: status);
    }
  }

  /// Pull the problem `type` slug and `detail` out of an error body, or null if
  /// it is not an RFC 7807 problem document.
  ///
  /// The slug is the last path segment of the `type` URL, matched rather than
  /// the whole URL so the error identity does not depend on the hostname, which
  /// differs between environments.
  Map<String, String?>? _problem(dynamic data) {
    if (data is! Map) return null;
    final type = data['type'];
    final detail = data['detail'];
    if (type is! String && detail is! String) return null;
    return {
      'slug': type is String ? type.split('/').last : null,
      'detail': detail is String && detail.isNotEmpty ? detail : null,
    };
  }
}
