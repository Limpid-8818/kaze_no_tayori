/// 漂流页冒烟：三幕结构（未抽/封筒上桌/池空叙事）、画布裁剪不回归
/// （无「纯随机」hint、无中央信封图案按钮 r6）、开信 replace 进阅读器。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/features/drift/drift_screen.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Map<String, dynamic> _letterJson(String id) => {
  'id': id,
  'blocks': const [
    {'type': 'text', 'text': '傍晚的海边风很大'},
  ],
  'poem': null,
  'addressee': '拾到它的人',
  'theme_id': 'natsu',
  'delivery_mode': 'drift',
  'place_label': '浙江 · 舟山',
  'weather': const {'text': '多云', 'temp_c': 26.0},
  'parent_letter_id': null,
  'counts': const {
    'read': 0,
    'resonance': 1,
    'voice': 0,
    'reply': 0,
    'saved': 0,
  },
  'created_at': '2026-08-24T10:00:00Z',
};

DioException _driftPoolEmpty() => DioException(
  requestOptions: RequestOptions(
    path: '/v1/drift/next',
    baseUrl: 'http://test',
  ),
  response: Response(
    requestOptions: RequestOptions(
      path: '/v1/drift/next',
      baseUrl: 'http://test',
    ),
    statusCode: 404,
    data: {
      'error': {'code': 'drift_pool_empty', 'message': '此刻还没有漂来的信'},
    },
  ),
);

class _Harness {
  _Harness(List<ScriptedResponse> script)
    : adapter = ScriptedAdapter(script),
      opened = <String>[];

  final ScriptedAdapter adapter;

  /// 阅读器路由被打开时记录 letterId（验证「开信」的目标）。
  final List<String> opened;

  Widget app() {
    final router = GoRouter(
      initialLocation: '/drift',
      routes: [
        GoRoute(path: '/drift', builder: (_, _) => const DriftScreen()),
        GoRoute(
          path: '/letters/:id',
          builder: (_, state) {
            opened.add(state.pathParameters['id']!);
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
  testWidgets('第一幕：副标题 + 抽一封信；无「纯随机」hint、无信封图案', (tester) async {
    final h = _Harness([]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('抽一封信'), findsOneWidget);
    expect(find.text('从陌生人的思绪里，\n随机抽一封。'), findsOneWidget);
    expect(find.textContaining('纯随机'), findsNothing);
    expect(find.byType(Envelope), findsNothing);
  });

  testWidgets('抽中：桌面上出现封筒，底栏开信/换一封在位', (tester) async {
    final h = _Harness([ScriptedResponse.ok(200, _letterJson('letter_a'))]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('抽一封信'));
    await tester.pumpAndSettle();

    expect(find.byType(Envelope), findsOneWidget);
    expect(find.text('开信'), findsOneWidget);
    expect(find.text('换一封'), findsOneWidget);
  });

  testWidgets('开信：replace 打开对应阅读器路由（拆封一次性仪式）', (tester) async {
    final h = _Harness([ScriptedResponse.ok(200, _letterJson('letter_a'))]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('抽一封信'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开信'));
    await tester.pumpAndSettle();

    expect(h.opened, ['letter_a']);
  });

  testWidgets('换一封到池空：呈现叙事态「此刻还没有漂来的信」', (tester) async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson('letter_a')),
      ScriptedResponse.fail(_driftPoolEmpty()),
    ]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('抽一封信'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('换一封'));
    await tester.pumpAndSettle();

    expect(find.text('此刻还没有漂来的信'), findsOneWidget);
    expect(find.byType(Envelope), findsNothing);
  });
}
