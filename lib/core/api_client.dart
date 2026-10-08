import 'package:dio/dio.dart';

import 'config.dart';
import 'secure_storage.dart';

/// Thrown by [ApiClient] for any non-2xx response with the backend's
/// `{error, code}` JSON error shape.
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  ApiException(this.message, {this.code, this.statusCode});

  @override
  String toString() => message;
}

/// Dio-based API client for the /api/mobile backend.
///
/// Injects the Bearer token on every request and calls [onUnauthorized]
/// whenever the backend returns 401, so the app can clear the session and
/// route to the login screen.
class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _storage.clear();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final SecureStorageService _storage;
  late final Dio _dio;

  /// Set by app wiring; invoked whenever a request comes back 401.
  void Function()? onUnauthorized;

  Dio get dio => _dio;

  Future<T> _unwrap<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) mapper,
  ) async {
    try {
      final response = await request();
      return mapper(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    String message = 'Something went wrong. Please try again.';
    String? code;
    if (data is Map<String, dynamic>) {
      message = data['error']?.toString() ?? message;
      code = data['code']?.toString();
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      message = 'Could not reach the server. Check your connection.';
    }
    return ApiException(message, code: code, statusCode: e.response?.statusCode);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _unwrap(
      () => _dio.get(path, queryParameters: query),
      (data) => data as Map<String, dynamic>,
    );
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _unwrap(
      () => _dio.get(path, queryParameters: query),
      (data) => data as List<dynamic>,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _unwrap(
      () => _dio.post(path, data: body ?? {}),
      (data) => (data ?? {}) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _unwrap(
      () => _dio.put(path, data: body ?? {}),
      (data) => (data ?? {}) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> deleteJson(String path) {
    return _unwrap(
      () => _dio.delete(path),
      (data) => (data ?? {}) as Map<String, dynamic>,
    );
  }

  /// For endpoints whose response shape isn't a strict Map or List (e.g.
  /// loosely-typed passthroughs of a tRPC procedure).
  Future<dynamic> getDynamic(String path, {Map<String, dynamic>? query}) {
    return _unwrap(
      () => _dio.get(path, queryParameters: query),
      (data) => data,
    );
  }
}
