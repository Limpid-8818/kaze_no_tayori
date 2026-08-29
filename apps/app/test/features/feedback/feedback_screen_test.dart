/// 反馈页（F11）冒烟：radio 选择、空正文禁用提交、提交成功切确认态、
/// 失败展示错误并在重新输入后清除。
///
/// 网络层走 ScriptedAdapter 脚本（与通知页测试同一基建）；
/// package_info_plus 需要显式 mock 初始值（FeedbackApi 读版本号）。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/features/feedback/feedback_screen.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

ScriptedResponse _ok() => ScriptedResponse.ok(201, {
  'id': 'fb_1',
  'category': 'suggestion',
  'status': 'open',
  'created_at': '2026-08-29T00:00:00+00:00',
});

ScriptedResponse _badRequest() => ScriptedResponse.ok(422, {
  'error': {'code': 'validation_error', 'message': '请求参数不合法', 'detail': null},
});

class _Harness {
  _Harness(List<ScriptedResponse> script) : adapter = ScriptedAdapter(script);

  final ScriptedAdapter adapter;

  Widget app() {
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
      child: MaterialApp(
        theme: KazeTheme.light(),
        home: const FeedbackScreen(),
      ),
    );
  }
}

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'kaze',
      packageName: 'dev.kaze',
      version: '9.9.9',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  testWidgets('初始：标题、两个类型选项、输入区与禁用的提交按钮', (tester) async {
    final h = _Harness([]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('反馈'), findsOneWidget);
    expect(find.text('遇到的问题'), findsOneWidget);
    expect(find.text('改进建议'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('寄出反馈'), findsOneWidget);

    // 空正文 → 主行动禁用（NatsuButton onPressed=null）
    final button = tester.widget<NatsuButton>(find.byType(NatsuButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('选类型 + 输入正文 + 提交：请求体带类型/正文/版本/平台，切确认态', (tester) async {
    final h = _Harness([_ok()]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('改进建议'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '希望多几种信纸皮肤');
    await tester.pump();

    await tester.tap(find.text('寄出反馈'));
    await tester.pumpAndSettle();

    final body = h.adapter.requests.single.data as Map<String, dynamic>;
    expect(body['category'], 'suggestion');
    expect(body['content'], '希望多几种信纸皮肤');
    expect(body['app_version'], '9.9.9');
    expect(body['platform'], isNotEmpty);

    expect(find.text('已经寄到了。'), findsOneWidget);
    expect(find.text('好的'), findsOneWidget);
  });

  testWidgets('提交失败：错误文案可见，重新输入清错，重试成功', (tester) async {
    final h = _Harness([_badRequest(), _ok()]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '这里有个问题');
    await tester.pump();
    await tester.tap(find.text('寄出反馈'));
    await tester.pumpAndSettle();

    expect(find.text('请求参数不合法'), findsOneWidget);
    expect(find.text('已经寄到了。'), findsNothing);

    // 输入即清错（不点提交也应消失）
    await tester.enterText(find.byType(TextField), '这里有个问题，第二次描述');
    await tester.pump();
    expect(find.text('请求参数不合法'), findsNothing);

    await tester.tap(find.text('寄出反馈'));
    await tester.pumpAndSettle();
    expect(find.text('已经寄到了。'), findsOneWidget);
  });
}
