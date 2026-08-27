/// 未读数控制器测试（F5）：初始 0、刷新取条数且带 unread_only 查询、
/// 失败静默保留旧值、decrement 不为负。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/controllers/unread_count_controller.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Map<String, dynamic> _notif(String id) => {
  'id': id,
  'type': 'reply',
  'letter_id': 'letter_$id',
  'parent_letter_id': 'parent_$id',
  'parent_place_label': '浙江 · 杭州',
  'is_read': false,
  'created_at': DateTime.now().toIso8601String(),
};

DioException _server() => DioException(
  requestOptions: RequestOptions(
    path: '/v1/me/notifications',
    baseUrl: 'http://test',
  ),
  response: Response(
    requestOptions: RequestOptions(
      path: '/v1/me/notifications',
      baseUrl: 'http://test',
    ),
    statusCode: 503,
    data: {
      'error': {'code': 'service_unavailable', 'message': 'x'},
    },
  ),
);

(ProviderContainer, ScriptedAdapter) _container(List<ScriptedResponse> script) {
  final adapter = ScriptedAdapter(script);
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(
        ApiClient(
          dio: Dio(
            BaseOptions(
              baseUrl: 'http://test',
              contentType: Headers.jsonContentType,
            ),
          )..httpClientAdapter = adapter,
          store: fakeSecureStore(),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container, adapter);
}

void main() {
  test('初始为 0，不触发任何请求', () {
    final (c, adapter) = _container([]);

    expect(c.read(unreadCountControllerProvider), 0);
    expect(adapter.requests, isEmpty);
  });

  test('refresh：计数等于未读条数，查询带 unread_only=true 与 limit=50', () async {
    final (c, adapter) = _container([
      ScriptedResponse.ok(200, {
        'items': [_notif('n1'), _notif('n2'), _notif('n3')],
        'next_cursor': null,
      }),
    ]);

    await c.read(unreadCountControllerProvider.notifier).refresh();

    expect(c.read(unreadCountControllerProvider), 3);

    final request = adapter.requests.single;
    expect(request.uri.path, '/v1/me/notifications');
    expect(request.uri.queryParameters['unread_only'], 'true');
    expect(request.uri.queryParameters['limit'], '50');
  });

  test('refresh 失败：静默保留旧值', () async {
    final (c, _) = _container([ScriptedResponse.fail(_server())]);

    await c.read(unreadCountControllerProvider.notifier).refresh();
    expect(c.read(unreadCountControllerProvider), 0);

    // 先成功拿到 2，再失败——保留 2 而不是清零
    final (c2, _) = _container([
      ScriptedResponse.ok(200, {
        'items': [_notif('n1'), _notif('n2')],
        'next_cursor': null,
      }),
      ScriptedResponse.fail(_server()),
    ]);
    final notifier = c2.read(unreadCountControllerProvider.notifier);
    await notifier.refresh();
    expect(c2.read(unreadCountControllerProvider), 2);
    await notifier.refresh();
    expect(c2.read(unreadCountControllerProvider), 2);
  });

  test('decrement：大于 0 减一；到 0 后不再往下', () async {
    final (c, _) = _container([
      ScriptedResponse.ok(200, {
        'items': [_notif('n1'), _notif('n2')],
        'next_cursor': null,
      }),
    ]);
    final notifier = c.read(unreadCountControllerProvider.notifier);

    await notifier.refresh();
    expect(c.read(unreadCountControllerProvider), 2);

    notifier.decrement();
    expect(c.read(unreadCountControllerProvider), 1);
    notifier.decrement();
    expect(c.read(unreadCountControllerProvider), 0);
    notifier.decrement();
    expect(c.read(unreadCountControllerProvider), 0); // 不为负
  });
}
