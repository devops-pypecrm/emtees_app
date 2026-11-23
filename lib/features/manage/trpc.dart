import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/providers.dart';

/// Minimal client for the web app's tRPC endpoints (same Bearer login as the rest of the app),
/// so the staff screens use exactly the same business rules as the web portal.
class Trpc {
  Trpc(this._dio);
  final Dio _dio;

  String get _base => '${AppConfig.socketBaseUrl}/api/trpc';

  Map<String, dynamic> _clean(Map<String, dynamic>? m) =>
      {for (final e in (m ?? {}).entries) if (e.value != null) e.key: e.value};

  Future<dynamic> query(String path, [Map<String, dynamic>? input]) async {
    try {
      final params = input == null ? null : {'input': jsonEncode({'json': _clean(input)})};
      final r = await _dio.get('$_base/$path', queryParameters: params);
      return _data(r.data);
    } on DioException catch (e) {
      throw TrpcException(_message(e));
    }
  }

  Future<dynamic> mutate(String path, [Map<String, dynamic>? input]) async {
    try {
      final r = await _dio.post('$_base/$path', data: {'json': _clean(input)});
      return _data(r.data);
    } on DioException catch (e) {
      throw TrpcException(_message(e));
    }
  }

  dynamic _data(dynamic body) {
    final result = body is Map ? body['result'] : null;
    final data = result is Map ? result['data'] : null;
    return data is Map ? data['json'] : data;
  }

  String _message(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['error'] is Map) {
      final j = (d['error'] as Map)['json'];
      if (j is Map && j['message'] != null) return j['message'].toString();
    }
    if (d is List && d.isNotEmpty && d.first is Map) {
      final j = ((d.first as Map)['error'] as Map?)?['json'];
      if (j is Map && j['message'] != null) return j['message'].toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class TrpcException implements Exception {
  TrpcException(this.message);
  final String message;
  @override
  String toString() => message;
}

final trpcProvider = Provider<Trpc>((ref) => Trpc(ref.watch(apiClientProvider).dio));
