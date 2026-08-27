/// 运行时 mock —— `--dart-define=USE_MOCK_API=true` 时接管全部网络。
///
/// 不起后端也能走通写信最小闭环（静默登录 → 选图上传 → 寄出）。
/// 只换 Dio 的 HttpClientAdapter，请求仍走真实 [ApiClient] 的解析与
/// 错误管线——mock 响应形状错了，会和真实后端一样在这里炸出来，
/// 契约不漂移。
///
/// 覆盖范围：写信流触达的端点 + 可降级模块（天气/逆地理）的罐头值。
/// 未覆盖的路径返回 404 错误体，提示补路由而不是静默成功。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class MockApiAdapter implements HttpClientAdapter {
  int _seq = 1;
  int _resonanceCount = 2;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 模拟真实网络节奏，让 loading 态可见
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final method = options.method.toUpperCase();
    final path = options.uri.path;

    if (method == 'POST' && path == '/v1/auth/device') {
      return _json(200, const {
        'access_token': 'mock.jwt.not-a-real-token',
        'token_type': 'bearer',
        'user_id': 'mock-user',
      });
    }
    if (method == 'POST' && path == '/v1/uploads/images') {
      return _json(201, {
        'url': 'https://mock.kaze.local/uploads/photo_$_seq.jpg',
      });
    }
    if (method == 'POST' &&
        (path == '/v1/letters' ||
            RegExp(r'^/v1/letters/[^/]+/replies$').hasMatch(path))) {
      return _json(201, _letterOwned(options));
    }
    // 读一封公开信：固定 id「mock_letter_1」可读，其余 404（读信空态可测）
    final letterMatch = RegExp(r'^/v1/letters/([^/]+)$').firstMatch(path);
    if (method == 'GET' && letterMatch != null) {
      return letterMatch.group(1) == 'mock_letter_1'
          ? _json(200, _letterPublic())
          : _json(404, const {
              'error': {
                'code': 'letter_not_found',
                'message': '信不存在或尚未漂到公开水域',
                'detail': null,
              },
            });
    }
    if (method == 'POST' &&
        RegExp(r'^/v1/letters/[^/]+/read$').hasMatch(path)) {
      return _json(204, null);
    }
    if (method == 'POST' &&
        RegExp(r'^/v1/letters/[^/]+/report$').hasMatch(path)) {
      return _json(204, null);
    }
    if (method == 'POST' &&
        RegExp(r'^/v1/letters/[^/]+/resonance$').hasMatch(path)) {
      return _json(201, {'resonance_count': ++_resonanceCount});
    }
    if (method == 'GET' && path == '/v1/weather/now') {
      return _json(200, const {'text': '晴', 'temp_c': 27.5, 'icon': 'clear'});
    }
    if (method == 'GET' && path == '/v1/geo/reverse') {
      return _json(200, const {'place_label': '浙江 · 杭州'});
    }
    if (method == 'GET' && path == '/v1/me/letters') {
      return _json(200, const {'items': <Object>[], 'next_cursor': null});
    }
    if (method == 'GET' && path == '/health') {
      return _json(200, const {'status': 'ok'});
    }
    return _json(404, {
      'error': {
        'code': 'not_found',
        'message': 'mock 未覆盖的路由: $method $path',
        'detail': null,
      },
    });
  }

  /// 回显请求体组装 LetterOwned —— 寄出什么就「落库」什么，方便核对。
  Map<String, Object?> _letterOwned(RequestOptions options) {
    final body = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : const <String, dynamic>{};
    return {
      'id': 'mock_letter_${_seq++}',
      'blocks': body['blocks'] ?? const <Object>[],
      'poem': null,
      'signature': body['signature'],
      'addressee': body['addressee'],
      'theme_id': body['theme_id'] ?? 'natsu',
      'theme_skin': null,
      'music_ref': null,
      'place_label': body['place_label'],
      'weather': body['weather'],
      'tags': const <String>[],
      'delivery_mode': body['delivery_mode'] ?? 'drift',
      'parent_letter_id': null,
      'counts': const {
        'read': 0,
        'resonance': 0,
        'voice': 0,
        'reply': 0,
        'saved': 0,
      },
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'lat': body['lat'],
      'lon': body['lon'],
    };
  }

  /// 固定种子信（mock_letter_1）——含文本/照片交替流，读信页 mock 数据源。
  Map<String, Object?> _letterPublic() {
    return {
      'id': 'mock_letter_1',
      'blocks': const [
        {'type': 'text', 'text': '傍晚的海边风很大，把想说的话都吹散了。'},
        {
          'type': 'photo',
          'ref': 'https://mock.kaze.local/uploads/photo_seed.jpg',
          'mood': 'backlit',
          'note': '逆光的防波堤',
        },
        {'type': 'text', 'text': '就把它们写进信里，交给风。'},
      ],
      'poem': null,
      'signature': '赶海的人',
      'addressee': null,
      'theme_id': 'natsu',
      'theme_skin': null,
      'music_ref': null,
      'place_label': '浙江 · 舟山',
      'weather': const {'text': '多云', 'temp_c': 26.0, 'icon': 'cloudy'},
      'tags': const <String>[],
      'delivery_mode': 'drift',
      'parent_letter_id': null,
      'counts': {
        'read': 3,
        'resonance': _resonanceCount,
        'voice': 0,
        'reply': 0,
        'saved': 0,
      },
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  ResponseBody _json(int status, Object? data) {
    final encoded = utf8.encode(jsonEncode(data));
    return ResponseBody(
      Stream<Uint8List>.fromIterable([Uint8List.fromList(encoded)]),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
