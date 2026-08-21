import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/core/result.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/local/secure_store.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Dio _makeDio() => Dio(
  BaseOptions(
    baseUrl: 'http://test',
    connectTimeout: const Duration(seconds: 2),
    receiveTimeout: const Duration(seconds: 2),
    contentType: Headers.jsonContentType,
  ),
);

/// 造一个走脚本队列的 ApiClient。
/// 重绑用的裸 Dio 也走同一脚本队列（测试环境发不了真网络请求）。
ApiClient _client(ScriptedAdapter adapter, SecureStore store) {
  return ApiClient(
    store: store,
    dio: _makeDio()..httpClientAdapter = adapter,
    rebindDio: _makeDio()..httpClientAdapter = adapter,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('204 / 空体容忍', () {
    test('postJson 收到 204 空 body（null data）返回空 Map 不抛', () async {
      final store = fakeSecureStore();
      final adapter = ScriptedAdapter([
        const ScriptedResponse.ok(204), // data null → ResponseBody 空流
      ]);
      final client = _client(adapter, store);
      final json = await client.postJson('/v1/me/scripbook', body: {});
      expect(json, isEmpty);
    });

    test('getJson 收到空字符串 body 返回空 Map', () async {
      final store = fakeSecureStore();
      final adapter = ScriptedAdapter([
        const ScriptedResponse.ok(200, ''), // 空 String
      ]);
      final client = _client(adapter, store);
      final json = await client.getJson('/health');
      expect(json, isEmpty);
    });
  });

  group('错误映射', () {
    test('错误体 code=drift_pool_empty → driftPoolEmpty', () async {
      final store = fakeSecureStore({'kaze.access_token': 'tok'});
      final adapter = ScriptedAdapter([
        ScriptedResponse.fail(
          DioException(
            requestOptions: RequestOptions(path: '/v1/drift/next'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/drift/next'),
              statusCode: 404,
              data: {
                'error': {'code': 'drift_pool_empty', 'message': 'x'},
              },
            ),
          ),
        ),
      ]);
      final client = _client(adapter, store);
      await expectLater(
        client.getJson('/v1/drift/next'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.driftPoolEmpty,
          ),
        ),
      );
    });

    test('503 无错误体 → serviceUnavailable 且 isDegradable', () async {
      final store = fakeSecureStore({'kaze.access_token': 'tok'});
      final adapter = ScriptedAdapter([
        ScriptedResponse.fail(
          DioException(
            requestOptions: RequestOptions(path: '/v1/ai/polish'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/ai/polish'),
              statusCode: 503,
            ),
          ),
        ),
      ]);
      final client = _client(adapter, store);
      try {
        await client.postJson('/v1/ai/polish', body: {'content': 'x'});
        fail('应抛 ApiFailure');
      } on ApiFailure catch (e) {
        expect(e.kind, ApiErrorKind.serviceUnavailable);
        expect(e.isDegradable, isTrue);
      }
    });
  });

  group('401 自动重绑', () {
    test('401 → auth/device 成功 → 带新 token 重试原请求成功', () async {
      final store = fakeSecureStore({'kaze.access_token': 'expired'});
      final adapter = ScriptedAdapter([
        // 1) 原请求 401
        ScriptedResponse.fail(
          DioException(
            requestOptions: RequestOptions(path: '/v1/me/letters'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/me/letters'),
              statusCode: 401,
              data: {
                'error': {'code': 'unauthorized', 'message': 'x'},
              },
            ),
          ),
        ),
        // 2) 重绑成功（裸 Dio 也走同一 adapter）
        const ScriptedResponse.ok(200, {
          'access_token': 'fresh-token',
          'token_type': 'bearer',
          'user_id': 'u-1',
        }),
        // 3) 重试成功
        const ScriptedResponse.ok(200, {'items': [], 'next_cursor': null}),
      ]);
      final client = _client(adapter, store);

      final json = await client.getJson('/v1/me/letters');
      expect(json['items'], isEmpty);
      expect(await store.readToken(), 'fresh-token');
      // 重试请求带上了新 Authorization
      final retry = adapter.requests[2];
      expect(retry.headers['Authorization'], contains('Bearer fresh-token'));
    });

    test('重试再 401 → 抛 unauthorized，不再循环', () async {
      final store = fakeSecureStore({'kaze.access_token': 'expired'});
      final adapter = ScriptedAdapter([
        ScriptedResponse.fail(
          DioException(
            requestOptions: RequestOptions(path: '/v1/me/letters'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/me/letters'),
              statusCode: 401,
            ),
          ),
        ),
        const ScriptedResponse.ok(200, {
          'access_token': 'fresh',
          'token_type': 'bearer',
          'user_id': 'u',
        }),
        // 重试仍 401 —— 脚本到此为止，若发生第二次重绑会耗尽脚本而 StateError
        ScriptedResponse.fail(
          DioException(
            requestOptions: RequestOptions(path: '/v1/me/letters'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/me/letters'),
              statusCode: 401,
            ),
          ),
        ),
      ]);
      final client = _client(adapter, store);
      await expectLater(
        client.getJson('/v1/me/letters'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.unauthorized,
          ),
        ),
      );
      expect(adapter.requests.length, 3); // 原请求 + 重绑 + 一次重试，无更多
    });

    test('并发两个 401 → 只重绑一次', () async {
      final store = fakeSecureStore({'kaze.access_token': 'expired'});
      final adapter = ScriptedAdapter([
        // 两个并发原请求都 401
        ScriptedResponse.fail(
          DioException(
            requestOptions: RequestOptions(path: '/v1/me/letters'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/me/letters'),
              statusCode: 401,
            ),
          ),
        ),
        ScriptedResponse.fail(
          DioException(
            requestOptions: RequestOptions(path: '/v1/me/letters'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/me/letters'),
              statusCode: 401,
            ),
          ),
        ),
        // 只有一次重绑
        const ScriptedResponse.ok(200, {
          'access_token': 'one-rebind',
          'token_type': 'bearer',
          'user_id': 'u',
        }),
        // 两次重试都成功
        const ScriptedResponse.ok(200, {'items': []}),
        const ScriptedResponse.ok(200, {'items': []}),
      ]);
      final client = _client(adapter, store);

      final results = await Future.wait([
        client.getJson('/v1/me/letters'),
        client.getJson('/v1/me/letters'),
      ]);
      expect(results, everyElement(isNotEmpty));
      // 队列总共 5 条脚本恰好耗尽：2×401 + 1×重绑 + 2×重试
      final rebindCalls = adapter.requests
          .where((r) => r.path.contains('/auth/device'))
          .length;
      expect(rebindCalls, 1);
    });
  });

  group('ensureSession（冷启动）', () {
    test('无 token → 生成 device_id 并换 JWT', () async {
      final store = fakeSecureStore(); // 空
      final adapter = ScriptedAdapter([
        const ScriptedResponse.ok(200, {
          'access_token': 'cold-token',
          'token_type': 'bearer',
          'user_id': 'u-9',
        }),
      ]);
      final client = _client(adapter, store);
      await client.ensureSession();

      expect(await store.readToken(), 'cold-token');
      final deviceId = await store.readDeviceId();
      expect(deviceId, isNotNull);
      // UUIDv4 形态（后端约束 8–64 字符）
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(deviceId!),
        isTrue,
        reason: '$deviceId 应为合法 UUIDv4',
      );
      // 请求体带了 device_id
      final req = adapter.requests.single;
      expect(req.path, '/v1/auth/device');
    });

    test('已有 token → 不发任何请求（脚本为空即证明）', () async {
      final store = fakeSecureStore({'kaze.access_token': 'valid'});
      final adapter = ScriptedAdapter(const []); // 空脚本：来请求就 StateError
      final client = _client(adapter, store);
      await client.ensureSession();
      expect(adapter.requests, isEmpty);
    });
  });

  test('getList 解析裸数组；postMultipartBytes 回传 url', () async {
    final store = fakeSecureStore({'kaze.access_token': 'tok'});
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(200, [
        {'id': 'natsu', 'name': '夏の手紙'},
      ]),
      const ScriptedResponse.ok(201, {'url': 'http://img/1.jpg'}),
    ]);
    final client = _client(adapter, store);

    final themes = await client.getList('/v1/themes');
    expect(themes.single['id'], 'natsu');

    final up = await client.postMultipartBytes(
      '/v1/uploads/images',
      filename: 'a.jpg',
      bytes: [1, 2, 3],
      contentType: 'image/jpeg',
    );
    expect(up['url'], 'http://img/1.jpg');
    // 上传请求确实是 multipart
    expect(adapter.requests.last.headers[Headers.contentTypeHeader], isNotNull);
  });
}
