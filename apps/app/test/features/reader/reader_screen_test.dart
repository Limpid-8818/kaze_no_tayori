/// 读信页组件测试：ready 渲染（无作者位）、404/网络空态、共鸣回显、
/// 回信入口带 parent。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/features/reader/reader_screen.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

/// 纯文本信：测试环境里不出现网络图（cached_network_image 会真发请求）。
Map<String, dynamic> _letterJson() => {
  'id': 'letter_1',
  'blocks': const [
    {'type': 'text', 'text': '傍晚的海边风很大'},
  ],
  'theme_id': 'natsu',
  'delivery_mode': 'drift',
  'place_label': '浙江 · 舟山',
  'weather': const {'text': '多云', 'temp_c': 26.0},
  'signature': '赶海的人',
  'parent_letter_id': null,
  'counts': const {
    'read': 3,
    'resonance': 2,
    'voice': 0,
    'reply': 0,
    'saved': 0,
  },
  'created_at': '2026-08-26T10:00:00Z',
};

DioException _notFound(String path) => DioException(
  requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
  response: Response(
    requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
    statusCode: 404,
    data: {
      'error': {'code': 'letter_not_found', 'message': 'x'},
    },
  ),
);

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
  _Harness(List<ScriptedResponse> script)
    : adapter = ScriptedAdapter(script),
      pushed = <String>[];

  final ScriptedAdapter adapter;

  /// /write 路由被 push 时记录完整位置（验回信入口参数）。
  final List<String> pushed;

  Widget app() {
    final router = GoRouter(
      initialLocation: '/letters/letter_1',
      routes: [
        GoRoute(
          path: '/letters/:id',
          builder: (_, state) =>
              ReaderScreen(letterId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/write',
          builder: (_, state) {
            pushed.add('/write?parent=${state.uri.queryParameters['parent']}');
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
  testWidgets('ready：信纸渲染正文/署名，底部共鸣与回信在位', (tester) async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.byType(LetterReading), findsOneWidget);
    expect(find.text('傍晚的海边风很大'), findsOneWidget);
    expect(find.text('赶海的人'), findsOneWidget);
    expect(find.byType(NatsuResonance), findsOneWidget);
    expect(find.text('回以一封信'), findsOneWidget);
  });

  testWidgets('404：空态文案居中大卡片，无中间按钮，返回交给 AppBar', (tester) async {
    final h = _Harness([ScriptedResponse.fail(_notFound('/x'))]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('这封信不在了'), findsOneWidget);
    expect(find.text('可能已被删除或下架'), findsOneWidget);
    expect(find.text('返回'), findsNothing);
    expect(find.text('再试一次'), findsNothing);
    expect(find.text('回以一封信'), findsNothing);
  });

  testWidgets('服务错误：空态 + 再试一次可恢复', (tester) async {
    final h = _Harness([
      ScriptedResponse.fail(_server('/v1/letters/letter_1')),
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('没能加载这封信'), findsOneWidget);

    await tester.tap(find.text('再试一次'));
    await tester.pumpAndSettle();
    expect(find.byType(LetterReading), findsOneWidget);
  });

  testWidgets('点共鸣：落章后出现句子式计数', (tester) async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      ScriptedResponse.ok(201, {'resonance_count': 3}),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // 行动字「共鸣」在 Text.rich 里，find.text 不匹配——直接点组件
    await tester.tap(find.byType(NatsuResonance));
    await tester.pumpAndSettle();

    expect(find.text('3 个陌生人也曾有过这样的时刻'), findsOneWidget);
  });

  testWidgets('回以一封信：带 parent 跳写信路由', (tester) async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('回以一封信'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['/write?parent=letter_1']);
  });

  testWidgets('「更多」菜单：记入抄本常驻，选中后 POST 落库并冒提示', (tester) async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      const ScriptedResponse.ok(204),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('记入抄本'), findsOneWidget);
    expect(find.text('举报'), findsOneWidget);

    await tester.tap(find.text('记入抄本'));
    // 菜单退场 + 保存往返落地（不做全量 settle，好抓 toast 在场瞬间）
    await tester.pump(const Duration(milliseconds: 400));

    final request = h.adapter.requests.last;
    expect(request.method, 'POST');
    expect(request.uri.path, '/v1/me/scripbook');
    expect(find.byType(NatsuToast), findsOneWidget);

    // 收尾把 toast 的定时器走完，避免测试悬挂计时器报错
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
