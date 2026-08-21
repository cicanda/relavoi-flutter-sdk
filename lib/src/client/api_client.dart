import 'package:dio/dio.dart';
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

  RelavoiException _mapError(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data?.toString() ?? e.message ?? 'Unknown error';

    switch (status) {
      case 401:
        return AuthenticationException('Authentication failed');
      case 422:
        return ValidationException('Validation error: $body');
      case 429:
        return TierLimitException('Rate limit exceeded: $body');
      case 503:
        return SessionException('Service unavailable: $body', statusCode: 503);
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          return NetworkException('Network error: ${e.message}',
              originalError: e);
        }
        return RelavoiException('API error ($status): $body',
            statusCode: status);
    }
  }
}
