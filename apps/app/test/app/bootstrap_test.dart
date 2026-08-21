import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/bootstrap.dart';
import 'package:kazenotayori/data/api/api_client.dart';

import '../fakes/fake_secure_store.dart';
import '../fakes/scripted_adapter.dart';

Dio _makeDio() => Dio(
  BaseOptions(baseUrl: 'http://test', contentType: Headers.jsonContentType),
);

ApiClient _client(ScriptedAdapter adapter, store) {
  return ApiClient(
    store: store,
    dio: _makeDio()..httpClientAdapter = adapter,
    rebindDio: _makeDio()..httpClientAdapter = adapter,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('无 token：ensureSession 换到 JWT 并写入', () async {
    final store = fakeSecureStore();
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(200, {
        'access_token': 'boot-token',
        'token_type': 'bearer',
        'user_id': 'u-1',
      }),
    ]);
    await ensureSession(_client(adapter, store));
    expect(await store.readToken(), 'boot-token');
  });

  test('已有 token：不发请求', () async {
    final store = fakeSecureStore({'kaze.access_token': 'ok'});
    final adapter = ScriptedAdapter(const []);
    await ensureSession(_client(adapter, store));
    expect(adapter.requests, isEmpty);
  });

  test('认证失败：不抛（离线也照常进 App）', () async {
    final store = fakeSecureStore();
    final adapter = ScriptedAdapter([
      ScriptedResponse.fail(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/v1/auth/device'),
          reason: 'offline',
        ),
      ),
    ]);
    await ensureSession(_client(adapter, store)); // 不应 throw
    expect(await store.readToken(), isNull);
  });
}
