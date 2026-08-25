/// 唯一的网络出口。
///
/// **feature 里禁止直接 new Dio**（见根 CLAUDE.md §7）：JWT 注入、错误映射、
/// 超时、401 自动重绑都在这里统一处理，散出去就没法保证降级行为一致。
library;

import 'package:dio/dio.dart';

import '../../core/env.dart';
import '../../core/result.dart';
import '../local/secure_store.dart';

class ApiClient {
  ApiClient({Dio? dio, SecureStore? store, Dio? rebindDio})
    : _store = store ?? SecureStore(),
      _rebindDio =
          rebindDio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
            ),
          ),
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
        onError: (e, handler) async {
          await _onError(e, handler);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureStore _store;

  /// 重绑专用裸 Dio——不过本类 interceptor，天然无递归。
  /// 可注入是给测试用的（换成同一脚本队列的 adapter）。
  final Dio _rebindDio;

  /// in-flight 重绑合并：并发 401 时只发一次 /auth/device。
  Future<bool>? _rebindInFlight;

  /// 请求里防止重试循环的标记位（extra 不上线，只在本地 Dio 传递）。
  static const _kRetried = '__kaze_retried';

  // ---------- 会话 ----------

  /// 冷启动静默登录：已有长效 JWT（90 天）则跳过，否则用 device_id 换新。
  /// 失败由调用方（bootstrap）兜底吞掉——离线也照常进 App。
  Future<void> ensureSession() async {
    final token = await _store.readToken();
    if (token != null && token.isNotEmpty) return;
    final deviceId = await _store.ensureDeviceId();
    await _postDeviceAuth(deviceId);
  }

  /// 401 后重绑：合并并发的重绑请求，任何失败都返回 false
  /// （原始 401 会照常映射为 unauthorized，交给 UI/后续请求自愈）。
  Future<bool> _rebind() {
    return _rebindInFlight ??= _doRebind().whenComplete(
      () => _rebindInFlight = null,
    );
  }

  Future<bool> _doRebind() async {
    try {
      final deviceId = await _store.ensureDeviceId();
      await _postDeviceAuth(deviceId);
      return true;
    } on Exception {
      return false; // 离线 / 后端挂了 / device_id 被拒
    }
  }

  /// 用裸 Dio 发 /v1/auth/device。
  Future<void> _postDeviceAuth(String deviceId) async {
    final resp = await _rebindDio.post<dynamic>(
      '/v1/auth/device',
      data: {'device_id': deviceId},
    );
    final body = _bodyOrEmpty(resp.data);
    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      throw ApiFailure(
        ApiErrorKind.invalidResponse,
        '认证响应缺少 access_token',
        code: 'invalid_response',
      );
    }
    await _store.writeToken(token);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler handler) async {
    final opts = e.requestOptions;
    final isAuthPath = opts.path.contains('/auth/device');
    final retried = opts.extra[_kRetried] == true;
    if (e.response?.statusCode == 401 && !isAuthPath && !retried) {
      opts.extra[_kRetried] = true;
      final ok = await _rebind();
      if (ok) {
        final token = await _store.readToken();
        opts.headers['Authorization'] = 'Bearer $token';
        try {
          final resp = await _dio.fetch<dynamic>(opts);
          return handler.resolve(resp);
        } on DioException catch (e2) {
          return handler.next(e2);
        }
      }
    }
    handler.next(e);
  }

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

  /// 裸数组响应（如 /v1/themes、/v1/tags 不带 Page 包装）。
  Future<List<dynamic>> getList(String path) async {
    return _guard(() async {
      final resp = await _dio.get<dynamic>(path);
      final data = resp.data;
      if (data is List) return data;
      if (data is String && data.trim().isEmpty) return const [];
      throw const ApiFailure(
        ApiErrorKind.invalidResponse,
        '响应格式异常',
        code: 'invalid_response',
      );
    });
  }

  Future<void> delete(String path) async {
    await _guard(() async {
      await _dio.delete<void>(path);
      return const <String, dynamic>{};
    });
  }

  /// multipart 上传。只收 bytes，不依赖 image_picker——
  /// 拿 XFile 读字节是上层（F1 写信流）的事。
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

  // ---------- 内部 ----------

  /// 204 无 body / 空串 / Map 的统一兜底。Dio 对空体会给 null 或 ''，
  /// 取决于平台与 ResponseType，两者都按「空对象」处理。
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

  /// 把 endpoint 模型解析错误收束为稳定的协议失败，避免 TypeError 穿透到 UI，
  /// 也避免坏列表项被静默丢弃成“暂无内容”。
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

  List<T> decodeList<T>(
    List<dynamic> items,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return decode(() {
      return [
        for (var index = 0; index < items.length; index++)
          if (items[index] case final Map item)
            fromJson(Map<String, dynamic>.from(item))
          else
            throw FormatException('列表第 $index 项不是 JSON 对象'),
      ];
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
      final rawCode = err['code'];
      final rawMessage = err['message'];
      if (rawCode is String) code = rawCode;
      if (rawMessage is String) message = rawMessage;
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
    ApiErrorKind.invalidResponse => '服务返回了无法识别的内容',
    ApiErrorKind.unknown => '出了点意外',
  };
}
