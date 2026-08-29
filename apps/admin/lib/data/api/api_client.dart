/// 唯一的网络出口（管理端版）。
///
/// 与 apps/app 的 ApiClient 同源（跨 app 复制），差异点：
/// - 无匿名设备重绑——admin 是账号体系，401 一律清会话并回调
///   [onUnauthorized]（router 据此踢回 /login）
/// - 增加 patchJson
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/env.dart';
import '../../core/result.dart';
import '../session/session_store.dart';

class ApiClient {
  ApiClient({Dio? dio, AdminSessionStore? store, this.onUnauthorized})
    : _store = store ?? createSessionStore(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
              validateStatus: (code) => code != null && code < 500,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _store.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await _store.clear();
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(request: true, requestBody: true, error: true),
      );
    }
  }

  final Dio _dio;
  final AdminSessionStore _store;

  /// 401 时回调（清会话 + 路由踢回登录页）。
  final void Function()? onUnauthorized;

  // ---------- HTTP 动词 ----------

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _guard(() async {
      final resp = await _dio.get<dynamic>(path, queryParameters: query);
      return _bodyOrEmpty(resp.data);
    });
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    return _guard(() async {
      final resp = await _dio.post<dynamic>(path, data: body);
      return _bodyOrEmpty(resp.data);
    });
  }

  Future<Map<String, dynamic>> patchJson(String path, {Object? body}) async {
    return _guard(() async {
      final resp = await _dio.patch<dynamic>(path, data: body);
      return _bodyOrEmpty(resp.data);
    });
  }

  /// multipart 上传（种子信配图）。
  Future<Map<String, dynamic>> postMultipartBytes(
    String path, {
    required String filename,
    required List<int> bytes,
    String? contentType,
  }) async {
    return _guard(() async {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: contentType == null
              ? null
              : DioMediaType.parse(contentType),
        ),
      });
      final resp = await _dio.post<dynamic>(path, data: form);
      return _bodyOrEmpty(resp.data);
    });
  }

  // ---------- 解析 ----------

  /// 204 无 body / 空串 / Map 的统一兜底。
  Map<String, dynamic> _bodyOrEmpty(dynamic data) {
    if (data == null) return const {};
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.trim().isEmpty) return const {};
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiFailure(
      ApiErrorKind.invalidResponse,
      '响应格式异常',
      code: 'invalid_response',
    );
  }

  /// 把 endpoint 模型解析错误收束为稳定的协议失败。
  T decode<T>(T Function() parse) {
    try {
      return parse();
    } on ApiFailure {
      rethrow;
    } on FormatException catch (error) {
      throw ApiFailure(
        ApiErrorKind.invalidResponse,
        '服务响应与客户端契约不一致：${error.message}',
        code: 'invalid_response',
      );
    } on ArgumentError catch (error) {
      // json_serializable 的 enum 解码在服务端返回未知值时抛 ArgumentError。
      throw ApiFailure(
        ApiErrorKind.invalidResponse,
        '服务响应与客户端契约不一致：$error',
        code: 'invalid_response',
      );
    } on TypeError catch (error) {
      throw ApiFailure(
        ApiErrorKind.invalidResponse,
        '服务响应与客户端契约不一致：$error',
        code: 'invalid_response',
      );
    }
  }

  /// 把 Dio 异常翻译成 [ApiFailure]。validateStatus 放行了 4xx/5xx，
  /// 这里统一按后端错误体解析。
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
      final rawCode = err['code'];
      final rawMessage = err['message'];
      if (rawCode is String) code = rawCode;
      if (rawMessage is String) message = rawMessage;
    }

    final kind = switch (code) {
      'invalid_transition' => ApiErrorKind.conflict,
      'seed_letter_only' => ApiErrorKind.forbidden,
      'admin_forbidden' => ApiErrorKind.forbidden,
      'validation_error' => ApiErrorKind.validation,
      'service_unavailable' => ApiErrorKind.serviceUnavailable,
      _ => switch (status) {
        401 => ApiErrorKind.unauthorized,
        403 => ApiErrorKind.forbidden,
        404 => ApiErrorKind.notFound,
        409 => ApiErrorKind.conflict,
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
    ApiErrorKind.unauthorized => '会话已过期，请重新登录',
    ApiErrorKind.forbidden => '当前账号没有执行此操作的权限',
    ApiErrorKind.notFound => '目标不存在或已被删除',
    ApiErrorKind.validation => '提交的内容不太对',
    ApiErrorKind.conflict => '当前状态不允许这个操作',
    ApiErrorKind.featureDisabled => '这个能力暂时关闭了',
    ApiErrorKind.serviceUnavailable => '服务暂时不可用，稍后再试',
    ApiErrorKind.invalidResponse => '服务返回了无法识别的内容',
    ApiErrorKind.unknown => '出了点意外',
  };
}
