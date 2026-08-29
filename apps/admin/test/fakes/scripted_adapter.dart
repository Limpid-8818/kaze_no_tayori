/// 测试用 Dio HttpClientAdapter：按脚本队列依次吐响应。
///
/// 204 用真实空 body 流构造，覆盖「空体不炸」的路径。
/// 脚本耗尽再收到请求会抛 StateError——测试里这通常意味着
/// 实现多发了请求（比如重绑没被合并）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 一条脚本：要么成功响应（status + data），要么抛网络异常。
class ScriptedResponse {
  const ScriptedResponse.ok(this.status, [this.data]) : dioException = null;
  const ScriptedResponse.fail(this.dioException) : status = 200, data = null;

  final int status;
  final Object? data; // Map / List / String / null（204 场景）
  final DioException? dioException;
}

class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(Iterable<ScriptedResponse> script) : _queue = List.of(script);

  final List<ScriptedResponse> _queue;
  final List<RequestOptions> requests = [];

  /// 便捷：401 错误体。
  static DioException unauthorized(String path) => DioException(
    requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
    response: Response(
      requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
      statusCode: 401,
      data: {
        'error': {'code': 'unauthorized', 'message': 'x'},
      },
    ),
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_queue.isEmpty) {
      throw StateError('脚本耗尽，但收到了请求: ${options.uri}');
    }
    final next = _queue.removeAt(0);
    final exc = next.dioException;
    if (exc != null) {
      // onError 拦截器需要「响应已到达」形态的 DioException 才能重试。
      throw DioException(
        requestOptions: options,
        response: exc.response == null
            ? null
            : Response(
                requestOptions: options,
                statusCode: exc.response?.statusCode,
                data: exc.response?.data,
              ),
        error: exc.error,
        type: exc.response == null
            ? DioExceptionType.connectionError
            : DioExceptionType.badResponse,
      );
    }

    final body = next.data;
    if (body == null) {
      return ResponseBody(
        Stream<Uint8List>.fromIterable(const []),
        next.status,
        headers: {
          Headers.contentLengthHeader: ['0'],
        },
      );
    }
    final encoded = utf8.encode(body is String ? body : jsonEncode(body));
    return ResponseBody(
      Stream<Uint8List>.fromIterable([Uint8List.fromList(encoded)]),
      next.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
