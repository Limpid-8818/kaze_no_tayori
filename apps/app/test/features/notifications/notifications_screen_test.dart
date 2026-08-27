/// 回信告知页冒烟（F5）：未读/已读条目渲染、点击标已读并跳公开回信、
/// 空态叙事、错误态重试入口。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kazenotayori/app/controllers/unread_count_controller.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/features/notifications/notifications_screen.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Map<String, dynamic> _notifJson(
  String id, {
  required String letterId,
  String? place,
  bool isRead = false,
}) => {
  'id': id,
  'type': 'reply',
  'letter_id': letterId,
  'parent_letter_id': 'parent_$id',
  'parent_place_label': place,
  'is_read': isRead,
  'created_at': DateTime.now()
      .subtract(const Duration(hours: 4))
      .toIso8601String(),
};

ScriptedResponse _page(List<Map<String, dynamic>> items) =>
    ScriptedResponse.ok(200, {'items': items, 'next_cursor': null});

class _Harness {
  _Harness(this.script)
    : adapter = ScriptedAdapter(script),
      pushed = <String>[];

  final List<ScriptedResponse> script;
  final ScriptedAdapter adapter;
  final List<String> pushed;

  Widget app() {
    final router = GoRouter(
      initialLocation: '/me/notifications',
      routes: [
        GoRoute(
          path: '/me/notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/letters/:id',
          builder: (_, state) {
            pushed.add(state.pathParameters['id']!);
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
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
        unreadCountControllerProvider.overrideWith(_StubUnread.new),
      ],
      child: MaterialApp.router(routerConfig: router, theme: KazeTheme.light()),
    );
  }
}

class _StubUnread extends UnreadCountController {
  @override
  int build() => 0;
}

void main() {
  testWidgets('就绪：未读与已读条目各按其态渲染，页脚留白句', (tester) async {
    final h = _Harness([
      _page([
        _notifJson('n1', letterId: 'letter_a', place: '浙江 · 杭州'),
        _notifJson('n2', letterId: 'letter_b', place: null, isRead: true),
      ]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('你于 浙江 · 杭州 写的那封信，收到一封回信 ✦'), findsOneWidget);
    expect(find.text('你于 某地 写的那封信，收到一封回信 ✦'), findsOneWidget);
    expect(find.textContaining('小时前'), findsNWidgets(2));
    expect(find.text('只有这些了。风会继续送来回信的消息。'), findsOneWidget);

    // 列表从页首开始读（AppBar 下沿附近），不垂直居中浮在屏幕中部
    final firstCardTop = tester.getTopLeft(find.byType(Card).first).dy;
    expect(firstCardTop, lessThan(150));
  });

  testWidgets('点未读条目：先发已读上报，再跳公开回信本体', (tester) async {
    final h = _Harness([
      _page([_notifJson('n1', letterId: 'letter_reply_9', place: '上海')]),
      const ScriptedResponse.ok(204),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('收到一封回信'));
    await tester.pumpAndSettle();

    final readCall = h.adapter.requests.last;
    expect(readCall.method, 'POST');
    expect(readCall.uri.path, '/v1/me/notifications/n1/read');
    expect(h.pushed, ['letter_reply_9']);
  });

  testWidgets('空列表：「暂时没有回音」叙事空态', (tester) async {
    final h = _Harness([
      ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('暂时没有回音'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);
  });

  testWidgets('拉取失败：错误叙事 + 再试一次可恢复', (tester) async {
    final notFound = DioException(
      requestOptions: RequestOptions(path: '/x', baseUrl: 'http://test'),
      response: Response(
        requestOptions: RequestOptions(path: '/x', baseUrl: 'http://test'),
        statusCode: 503,
        data: {
          'error': {'code': 'service_unavailable', 'message': 'x'},
        },
      ),
    );
    final h = _Harness([
      ScriptedResponse.fail(notFound),
      _page([_notifJson('n1', letterId: 'letter_a')]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('没能拿到回信告知'), findsOneWidget);

    await tester.tap(find.text('再试一次'));
    await tester.pumpAndSettle();

    expect(find.textContaining('收到一封回信'), findsOneWidget);
  });
}
