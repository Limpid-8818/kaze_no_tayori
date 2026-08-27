/// 抄本页冒烟（F7）：摘要卡两形态渲染、点卡直读、空态引导发掘、
/// 错误重试、长按弹操作区的两段式移出（再想想可回退）、确认后卡片
/// 退场转空态 + toast；关弹层不回源、从阅读器返回恰一次静默刷新。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kazenotayori/app/router.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/features/scripbook/scripbook_screen.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Map<String, dynamic> _letterJson(
  String id, {
  String? poem,
  Duration ago = const Duration(hours: 4),
}) => {
  'id': id,
  'blocks': const [
    {'type': 'text', 'text': '在海堤上写完这封，浪来过两次，纸角湿了一点。'},
  ],
  'poem': poem,
  'theme_id': 'natsu',
  'delivery_mode': 'drift',
  'place_label': '浙江 · 舟山',
  'weather': const {'text': '晴', 'temp_c': 29.0},
  'parent_letter_id': null,
  'counts': const {
    'read': 0,
    'resonance': 0,
    'voice': 0,
    'reply': 0,
    'saved': 0,
  },
  'created_at': DateTime.now().subtract(ago).toIso8601String(),
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

class _Harness {
  _Harness(List<ScriptedResponse> script) : adapter = ScriptedAdapter(script);

  final ScriptedAdapter adapter;
  final pushed = <String>[];

  Widget app() {
    final router = GoRouter(
      initialLocation: '/me/scripbook',
      // 与生产一致挂上 routeObserver：RouteAware 的回焦刷新依赖它
      observers: [routeObserver],
      routes: [
        GoRoute(
          path: '/me/scripbook',
          builder: (_, _) => const ScripbookScreen(),
        ),
        GoRoute(
          path: '/letters/:id',
          builder: (_, state) {
            pushed.add(state.pathParameters['id']!);
            // AppBar 自动补返回键，供「从阅读器返回」用例驱动
            return Scaffold(appBar: AppBar(), body: const SizedBox());
          },
        ),
        GoRoute(
          path: '/discover',
          builder: (_, _) {
            pushed.add('/discover');
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
      ],
      child: MaterialApp.router(routerConfig: router, theme: KazeTheme.light()),
    );
  }
}

void main() {
  testWidgets('ready：带诗走俳句排版、无诗走预览位；点卡拆开重读', (tester) async {
    final h = _Harness([
      _page([
        _letterJson('saved_a', poem: '候鸟排成人字\n把我的问候带走\n往更南的南方'),
        _letterJson('saved_b'),
      ]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('候鸟排成人字'), findsOneWidget);
    expect(find.textContaining('浪来过两次'), findsOneWidget);

    await tester.tap(find.text('候鸟排成人字'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['saved_a']);
  });

  testWidgets('empty：给出「在读信页 ⋯ 收进」的叙事与去发掘的出口', (tester) async {
    final h = _Harness([_page(const [])]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('还没有收进一封信'), findsOneWidget);
    expect(find.textContaining('右上角'), findsOneWidget);

    await tester.tap(find.text('去发掘一封信'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['/discover']);
  });

  testWidgets('error：错误态可再试恢复', (tester) async {
    final h = _Harness([
      ScriptedResponse.fail(_server('/v1/me/scripbook')),
      _page([_letterJson('saved_a')]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('没能翻开你的抄本'), findsOneWidget);

    await tester.tap(find.text('再试一次'));
    await tester.pumpAndSettle();
    expect(find.textContaining('浪来过两次'), findsOneWidget);
  });

  testWidgets('长按弹出移出操作区：「再想想」从确认段回到说明段', (tester) async {
    final h = _Harness([
      _page([_letterJson('saved_a')]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('浪来过两次'));
    await tester.pumpAndSettle();
    expect(find.text('你收藏的这封信'), findsOneWidget);
    expect(find.text('移出抄本'), findsOneWidget);

    await tester.tap(find.text('移出抄本'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不是删除'), findsOneWidget);
    expect(find.text('确认移出'), findsOneWidget);

    await tester.tap(find.text('再想想'));
    await tester.pumpAndSettle();
    expect(find.text('移出抄本'), findsOneWidget);
    expect(find.text('确认移出'), findsNothing);
    // 只有开页那一次拉取——翻面没有发任何写请求
    expect(h.adapter.requests, hasLength(1));
  });

  testWidgets('两段确认移出最后一封：DELETE 落库、卡片退场转空态并冒提示', (tester) async {
    final h = _Harness([
      _page([_letterJson('saved_a')]),
      const ScriptedResponse.ok(204),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('浪来过两次'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移出抄本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认移出'));

    // 弹层退场 + 控制器往返落地（不做全量 settle，好抓 toast 在场瞬间）
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('还没有收进一封信'), findsOneWidget);
    expect(find.byType(NatsuToast), findsOneWidget);

    // 恰两次：开页 GET + 移出 DELETE；确认关闭弹层不再引发回源刷新
    expect(h.adapter.requests, hasLength(2));
    final request = h.adapter.requests.last;
    expect(request.method, 'DELETE');
    expect(request.uri.path, '/v1/me/scripbook/saved_a');

    // 收尾把 toast 的定时器走完，避免测试悬挂计时器报错
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('点纸缘关闭操作区不回源：弹层的开合不算页面回焦，零新增请求', (tester) async {
    final h = _Harness([
      _page([_letterJson('saved_a')]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('浪来过两次'));
    await tester.pumpAndSettle();
    // 点纸缘（scrim）关闭弹层
    await tester.tapAt(const Offset(60, 90));
    await tester.pumpAndSettle();

    expect(find.text('你收藏的这封信'), findsNothing);
    expect(h.adapter.requests, hasLength(1));
  });

  testWidgets('从阅读器返回：恰一次静默刷新（列表原位，不全页加载）', (tester) async {
    final h = _Harness([
      _page([_letterJson('saved_a')]),
      _page([_letterJson('saved_a')]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('浪来过两次'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 开页拉取 + 返回时静默刷新 = 2 次 GET；phase 停在 ready 不闪加载
    expect(h.adapter.requests, hasLength(2));
    for (final request in h.adapter.requests) {
      expect(request.method, 'GET');
      expect(request.uri.path, '/v1/me/scripbook');
    }
    expect(find.byType(NatsuSpinner), findsNothing);
  });
}
