/// 写信页组件测试：所见即所得的关键行为——落款实时上纸、宛名不上纸、
/// 留/投必选拦截、图片托盘的加号与上限。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kazenotayori/app/router.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/data/device/image_gateway.dart';
import 'package:kazenotayori/features/write/draft_store.dart';
import 'package:kazenotayori/features/write/widgets/editable_paper.dart';
import 'package:kazenotayori/features/write/write_controller.dart';
import 'package:kazenotayori/features/write/write_screen.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';
import 'write_controller_test.dart' show kTinyPng;

class _FakeImageGateway implements ImageGateway {
  _FakeImageGateway(this.images);

  final List<PickedImage> images;

  @override
  Future<List<PickedImage>> pickImages({required int maxCount}) async => images;
}

PickedImage _png() => PickedImage(bytes: List.of(kTinyPng), mime: 'image/png');

/// 组装带 overrides 的整棵测试树（Override 类型在 riverpod 3.4 不可
/// 直接命名，靠推断传递）。
///
/// testWidgets 的 FakeAsync 区里 dart:io 的异步调用在本机会挂死（实测），
/// 临时目录必须 createTempSync；涉及真实文件 IO 的交互包 tester.runAsync。
Future<Widget> _writeApp({
  List<PickedImage> images = const [],
  List<ScriptedResponse> script = const [],
}) async {
  final tempDir = Directory.systemTemp.createTempSync('kaze_write_ui');
  addTearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放，留给系统临时目录清理
    }
  });
  final adapter = ScriptedAdapter(script);
  final overrides = [
    imageGatewayProvider.overrideWithValue(_FakeImageGateway(images)),
    draftStoreProvider.overrideWithValue(
      DraftStore(baseDirFactory: () async => tempDir),
    ),
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
  ];
  final router = GoRouter(
    initialLocation: Routes.write,
    routes: [
      GoRoute(path: Routes.write, builder: (_, _) => const WriteScreen()),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router, theme: KazeTheme.light()),
  );
}

/// 冲掉防抖（500ms）与 toast（2.4s）的挂起计时器，避免用例结束报错。
Future<void> _flushTimers(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('初始渲染：信纸可编辑、托盘只有加号、寄往何处与寄出在位', (tester) async {
    await tester.pumpWidget(await _writeApp());
    await tester.pumpAndSettle();

    expect(find.byType(EditablePaper), findsOneWidget);
    // TextField 三处：信纸正文 + 收信人 + 落款
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byIcon(Icons.add), findsOneWidget); // 托盘加号
    expect(find.text('地点'), findsOneWidget);
    expect(find.text('收信人'), findsOneWidget);
    expect(find.text('落款'), findsOneWidget);
    expect(find.text('寄往何处'), findsOneWidget);
    expect(find.text('寄出'), findsOneWidget);
    expect(find.text('留在这里'), findsOneWidget);
    expect(find.text('投递出去'), findsOneWidget);
  });

  testWidgets('落款输入实时渲染在信纸上，收信人不渲染', (tester) async {
    await tester.pumpWidget(await _writeApp());
    await tester.pumpAndSettle();

    // TextField 顺序：信纸正文 → 收信人 → 落款
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), '小海');
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(EditablePaper),
        matching: find.text('小海'),
      ),
      findsOneWidget,
    );

    await tester.enterText(fields.at(1), '远方的你');
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(EditablePaper),
        matching: find.text('远方的你'),
      ),
      findsNothing,
    );
    await _flushTimers(tester);
  });

  testWidgets('不选留/投直接寄出会被拦下，提示不静默发请求', (tester) async {
    await tester.pumpWidget(await _writeApp());
    await tester.pumpAndSettle();

    // 先写字（否则先拦「信还没有写」，验证顺序也是契约）
    await tester.enterText(find.byType(TextField).at(0), '写了一句话');
    await tester.pump();

    // 寄出按钮在 600px 视口的折叠线以下，先滚到可见再点
    await tester.ensureVisible(find.text('寄出'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('寄出'));
    await tester.pump();
    expect(find.text('还没有选择寄往何处'), findsOneWidget);
    await _flushTimers(tester);
  });

  testWidgets('插入照片后托盘按信内顺序显示，满三张加号消失', (tester) async {
    await tester.pumpWidget(
      await _writeApp(
        images: [_png(), _png(), _png()],
        script: [
          ScriptedResponse.ok(201, {'url': 'https://t/u1.jpg'}),
          ScriptedResponse.ok(201, {'url': 'https://t/u2.jpg'}),
          ScriptedResponse.ok(201, {'url': 'https://t/u3.jpg'}),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WriteScreen)),
    );

    await tester.enterText(find.byType(TextField).at(0), '前');
    await tester.pump();
    // 插图含真实文件 IO（草稿图片落盘），回真实事件循环执行
    await tester.runAsync(
      () =>
          container.read(writeControllerProvider.notifier).addPhotosAtCursor(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(writeControllerProvider).photoCount, 3);
    // 三张照片渲染（纸面 PhotoCard + 托盘缩略图，各 3）
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is FileImage,
      ),
      findsNWidgets(6),
    );
    expect(find.byIcon(Icons.add), findsNothing); // 满三张，加号退场
    await _flushTimers(tester);
  });
}
