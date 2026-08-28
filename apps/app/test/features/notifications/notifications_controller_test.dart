/// 回信控制器测试（F5）：列表加载与叙事句映射、地点缺省回退、
/// 标记已读联动未读数、失败静默不打断阅读。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/controllers/unread_count_controller.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/features/notifications/notifications_controller.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

/// 未读数替身：记录 decrement 调用，验证单向同步。
class _SpyUnread extends UnreadCountController {
  @override
  int build() => 2;

  int decCalls = 0;

  @override
  void decrement() {
    decCalls += 1;
    state = state - 1;
  }
}

Map<String, dynamic> _notifJson(
  String id, {
  required String letterId,
  String? place,
  bool isRead = false,
  DateTime? parentDate,
}) => {
  'id': id,
  'type': 'reply',
  'letter_id': letterId,
  'parent_letter_id': 'parent_$id',
  'parent_place_label': place,
  'parent_letter_date': parentDate?.toIso8601String(),
  'is_read': isRead,
  'created_at': DateTime.now()
      .subtract(const Duration(hours: 4))
      .toIso8601String(),
};

ScriptedResponse _page(List<Map<String, dynamic>> items) =>
    ScriptedResponse.ok(200, {'items': items, 'next_cursor': null});

DioException _server(String path) => DioException(
  requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
  response: Response(
    requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
    statusCode: 503,
    data: {
      'error': {'code': 'service_unavailable', 'message': 'x'},
    },
  ),
);

void main() {
  late _SpyUnread spy;
  late ScriptedAdapter adapter;

  ProviderContainer container(List<ScriptedResponse> script) {
    adapter = ScriptedAdapter(script);
    final c = ProviderContainer(
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
        unreadCountControllerProvider.overrideWith(() {
          spy = _SpyUnread();
          return spy;
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    spy = _SpyUnread();
  });

  test('就绪：叙事句映射「你于 {写信日} 在 {地点} …收到一封回信」，相对时间在位', () async {
    final c = container([
      _page([
        _notifJson(
          'n1',
          letterId: 'letter_a',
          place: '浙江 · 杭州',
          parentDate: DateTime(2026, 8, 12),
        ),
        // 旧响应无写信日期：回退为不带日期的原句；地点缺省回退「某地」
        _notifJson('n2', letterId: 'letter_b', isRead: true),
      ]),
    ]);

    await c.read(notificationsControllerProvider.notifier).start();

    final state = c.read(notificationsControllerProvider);
    expect(state.phase, NotificationsPhase.ready);
    expect(state.items, hasLength(2));
    expect(state.items[0].message, '你于 8月12日 在 浙江 · 杭州 写的那封信，收到一封回信');
    expect(state.items[0].timeLabel, contains('小时前'));
    expect(state.items[0].isRead, isFalse);
    expect(state.items[1].message, '你于 某地 写的那封信，收到一封回信');
    expect(state.items[1].isRead, isTrue);
  });

  test('拉取失败：error 态，不碰未读数', () async {
    final c = container([
      ScriptedResponse.fail(_server('/v1/me/notifications')),
    ]);

    await c.read(notificationsControllerProvider.notifier).start();

    expect(
      c.read(notificationsControllerProvider).phase,
      NotificationsPhase.error,
    );
    expect(spy.decCalls, 0);
  });

  test('标记已读：本地翻转 + 单向扣减未读数（恰一次）', () async {
    final c = container([
      _page([_notifJson('n1', letterId: 'letter_a', place: '浙江 · 杭州')]),
      const ScriptedResponse.ok(204),
    ]);
    final controller = c.read(notificationsControllerProvider.notifier);
    await controller.start();

    await controller.markRead('n1');

    expect(c.read(notificationsControllerProvider).items.single.isRead, isTrue);
    expect(spy.decCalls, 1);

    final readRequest = adapter.requests.last;
    expect(readRequest.method, 'POST');
    expect(readRequest.uri.path, '/v1/me/notifications/n1/read');
  });

  test('重复标记：已读条目直接短路，不发请求也不扣减', () async {
    final c = container([
      _page([_notifJson('n1', letterId: 'letter_a', isRead: true)]),
    ]);
    final controller = c.read(notificationsControllerProvider.notifier);
    await controller.start();

    await controller.markRead('n1');

    expect(adapter.requests, hasLength(1)); // 只有开页那一次拉取
    expect(spy.decCalls, 0);
  });

  test('上报失败：条目保持未读，不扣减，也不抛错挡住去读信的路', () async {
    final c = container([
      _page([_notifJson('n1', letterId: 'letter_a', place: '上海')]),
      ScriptedResponse.fail(_server('/v1/me/notifications/n1/read')),
    ]);
    final controller = c.read(notificationsControllerProvider.notifier);
    await controller.start();

    await controller.markRead('n1');

    expect(
      c.read(notificationsControllerProvider).items.single.isRead,
      isFalse,
    );
    expect(spy.decCalls, 0);
  });
}
