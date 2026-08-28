/// 我的信页冒烟（F6）：四态徽标渲染、公开信点按直读、长按/点按弹
/// 操作区、两段式下架确认（再想想可回退）、确认后徽标翻转 + toast。
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
import 'package:kazenotayori/features/my_letters/my_letters_screen.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Map<String, dynamic> _ownedJson(
  String id, {
  required String status,
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
  'status': status,
};

ScriptedResponse _page(List<Map<String, dynamic>> items) =>
    ScriptedResponse.ok(200, {'items': items, 'next_cursor': null});

class _Harness {
  _Harness(List<ScriptedResponse> script) : adapter = ScriptedAdapter(script);

  final ScriptedAdapter adapter;
  final pushed = <String>[];

  Widget app() {
    final router = GoRouter(
      initialLocation: '/me/letters',
      // 与生产一致挂上 routeObserver：RouteAware 的回焦刷新依赖它
      observers: [routeObserver],
      routes: [
        GoRoute(
          path: '/me/letters',
          builder: (_, _) => const MyLettersScreen(),
        ),
        GoRoute(
          path: '/letters/:id',
          builder: (_, state) {
            pushed.add(state.pathParameters['id']!);
            // AppBar 自动补返回键，供「从阅读器返回」用例驱动
            return Scaffold(appBar: AppBar(), body: const SizedBox());
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
  testWidgets('四态徽标渲染；公开卡点按直读，非公开卡点按留在原地弹操作区', (tester) async {
    final h = _Harness([
      _page([
        _ownedJson('mine_a', status: 'public', poem: '候鸟排成人字\n把我的问候带走\n往更南的南方'),
        _ownedJson('mine_b', status: 'pending'),
      ]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('公开中'), findsOneWidget);
    expect(find.text('审核中'), findsOneWidget);
    expect(find.text('候鸟排成人字 把我的问候带走 往更南的南方'), findsOneWidget);

    // 公开信：点击 = 拆开重读
    await tester.tap(find.text('候鸟排成人字 把我的问候带走 往更南的南方'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['mine_a']);
  });

  testWidgets('点按审核中的卡：不进阅读器（404 由交互层拦截），改弹状态解释与动作', (tester) async {
    final h = _Harness([
      _page([_ownedJson('mine_b', status: 'pending')]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('浪来过两次'));
    await tester.pumpAndSettle();

    expect(h.pushed, isEmpty);
    expect(find.text('你写的这封信'), findsOneWidget);
    expect(find.text('还在审核中，通过后才会出发。'), findsOneWidget);
    // 段一只有这一个动作；未发任何写请求
    expect(find.text('下架这封信'), findsOneWidget);
    expect(h.adapter.requests, hasLength(1));
  });

  testWidgets('关闭操作区不回源：弹层的开合不算页面回焦，零新增请求', (tester) async {
    final h = _Harness([
      _page([_ownedJson('mine_b', status: 'pending')]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('浪来过两次'));
    await tester.pumpAndSettle();
    // 点纸缘（scrim）关闭弹层
    await tester.tapAt(const Offset(60, 90));
    await tester.pumpAndSettle();

    expect(find.text('你写的这封信'), findsNothing);
    // 只有开页那一次拉取——没有隐藏的「回焦刷新」
    expect(h.adapter.requests, hasLength(1));
  });

  testWidgets('从阅读器返回：恰一次静默刷新（列表原位，不全页加载）', (tester) async {
    final h = _Harness([
      _page([_ownedJson('mine_a', status: 'public')]),
      _page([_ownedJson('mine_a', status: 'public')]),
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
      expect(request.uri.path, '/v1/me/letters');
    }
    expect(find.byType(NatsuSpinner), findsNothing);
  });

  testWidgets('长按弹出操作区：「再想想」从确认段回到解释段', (tester) async {
    final h = _Harness([
      _page([_ownedJson('mine_a', status: 'public')]),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('浪来过两次'));
    await tester.pumpAndSettle();
    expect(find.text('下架这封信'), findsOneWidget);

    await tester.tap(find.text('下架这封信'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不是删除'), findsOneWidget);
    expect(find.text('确认下架'), findsOneWidget);

    await tester.tap(find.text('再想想'));
    await tester.pumpAndSettle();
    expect(find.text('下架这封信'), findsOneWidget);
    expect(find.text('确认下架'), findsNothing);
  });

  testWidgets('两段确认下架：DELETE 落库，徽标原地翻转「已下架」并冒提示', (tester) async {
    final h = _Harness([
      _page([
        _ownedJson('mine_a', status: 'public', poem: '候鸟排成人字\n把我的问候带走\n往更南的南方'),
      ]),
      const ScriptedResponse.ok(204),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // 带诗卡的诗注记压成一行，长按目标取注记行
    await tester.longPress(find.text('候鸟排成人字 把我的问候带走 往更南的南方'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下架这封信'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认下架'));

    // 弹层退场 + 控制器往返落地（不做全量 settle，好抓 toast 在场瞬间）
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('已下架'), findsOneWidget);
    expect(find.byType(NatsuToast), findsOneWidget);

    // 恰两次：开页 GET + 下架 DELETE；确认关闭弹层不再引发回源刷新
    expect(h.adapter.requests, hasLength(2));
    final request = h.adapter.requests.last;
    expect(request.method, 'DELETE');
    expect(request.uri.path, '/v1/me/letters/mine_a');

    // 收尾把 toast 的定时器走完，避免测试悬挂计时器报错
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
