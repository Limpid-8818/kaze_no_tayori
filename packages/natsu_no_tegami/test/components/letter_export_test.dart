import 'dart:typed_data';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';

/// toImage/toByteData 的 PNG 编码走真实异步（平台线程），testWidgets 的
/// FakeAsync 区等不到它的回调——必须用 tester.runAsync 放出伪时间循环。
Future<Uint8List?> capture(WidgetTester tester, GlobalKey key,
        {double pixelRatio = 2.0}) =>
    tester.runAsync<Uint8List?>(
        () => captureLetterPng(key, pixelRatio: pixelRatio));

void main() {
  testWidgets('captureLetterPng 返回 PNG 字节（magic bytes 校验）',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LetterExportBoundary(
            boundaryKey: key,
            child: const SizedBox(
              width: 100,
              height: 50,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(); // 帧落定

    final bytes = await capture(tester, key);
    expect(bytes, isNotNull);
    // PNG magic: \x89 P N G \r \n \x1a \n
    expect(bytes!.sublist(0, 8),
        const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  });

  testWidgets('pixelRatio=2 时光栅宽 = 逻辑宽 × 2', (tester) async {
    // 固定测试视口，保证逻辑宽确定
    tester.view.physicalSize = const Size(300, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LetterExportBoundary(
            boundaryKey: key,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      ),
    ));
    await tester.pump();

    final bytes = await capture(tester, key, pixelRatio: 2.0);
    expect(bytes, isNotNull);
    // IHDR 宽度 = bytes 16..20（大端）——不引第三方解码器，手解 PNG 头
    final width = ByteData.sublistView(bytes!, 16, 20).getUint32(0);
    expect(width, 200);
  });

  testWidgets('key 未挂载 → 返回 null 不抛', (tester) async {
    final key = GlobalKey();
    final bytes = await capture(tester, key);
    expect(bytes, isNull);
  });

  testWidgets('LetterExportBoundary 内是 RenderRepaintBoundary', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LetterExportBoundary(
          boundaryKey: key,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    ));
    final ro = key.currentContext!.findRenderObject();
    expect(ro, isA<RenderRepaintBoundary>());
  });

  test('无障碍环境 sanity：true 断言可达', () {
    // 占位防 suite 只含 testWidgets 时误报——真实断言在上方各用例
    expect(PlatformDispatcher.instance.views.isEmpty, isFalse);
  });
}
