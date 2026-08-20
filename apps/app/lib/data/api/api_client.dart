/// 唯一的网络出口。
///
/// **feature 里禁止直接 new Dio**（见根 CLAUDE.md §7）：JWT 注入、错误映射、
/// 超时都在这里统一处理，散出去就没法保证降级行为一致。
library;

import 'package:dio/dio.dart';

import '../../core/env.dart';
import '../../core/result.dart';
import '../local/secure_store.dart';

class ApiClient {
  ApiClient({Dio? dio, SecureStore? store})
    : _store = store ?? SecureStore(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _store.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureStore _store;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _guard(() async {
      final resp = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      return resp.data ?? const {};
    });
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    return _guard(() async {
      final resp = await _dio.post<Map<String, dynamic>>(path, data: body);
      return resp.data ?? const {};
    });
  }

  Future<void> delete(String path) async {
    await _guard(() async {
      await _dio.delete<void>(path);
      return const <String, dynamic>{};
    });
  }

  /// 把 Dio 异常翻译成 [ApiFailure]，让 UI 能区分「该降级」与「该报错」。
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiFailure _mapError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? code;
    String? message;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      code = err['code'] as String?;
      message = err['message'] as String?;
    }

    // 后端统一错误体的 code 优先（见 docs/API_CONTRACT.md）
    final kind = switch (code) {
      'drift_pool_empty' => ApiErrorKind.driftPoolEmpty,
      'feature_disabled' => ApiErrorKind.featureDisabled,
      'service_unavailable' => ApiErrorKind.serviceUnavailable,
      'validation_error' => ApiErrorKind.validation,
      _ => switch (status) {
        401 => ApiErrorKind.unauthorized,
        404 => ApiErrorKind.notFound,
        422 => ApiErrorKind.validation,
        503 => ApiErrorKind.serviceUnavailable,
        null => ApiErrorKind.network,
        _ => ApiErrorKind.unknown,
      },
    };

    return ApiFailure(
      kind,
      message ?? _fallbackMessage(kind),
      code: code,
      statusCode: status,
    );
  }

  String _fallbackMessage(ApiErrorKind kind) => switch (kind) {
    ApiErrorKind.network => '连不上服务器，检查一下网络',
    ApiErrorKind.unauthorized => '身份已过期，重新进入即可',
    ApiErrorKind.notFound => '这封信不在了',
    ApiErrorKind.validation => '有些内容还不太对',
    ApiErrorKind.featureDisabled => '这个能力暂时关闭了',
    ApiErrorKind.serviceUnavailable => '服务暂时不可用，稍后再试',
    ApiErrorKind.driftPoolEmpty => '此刻还没有漂来的信',
    ApiErrorKind.unknown => '出了点意外',
  };
}
