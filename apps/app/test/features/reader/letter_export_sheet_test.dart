/// 导出预览 sheet 测试：长图预览与双动作在位、注入回调被触发、
/// 失败不关 sheet、成功关 sheet。
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/features/reader/widgets/letter_export_sheet.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../fakes/png_bytes.dart' as png_bytes;

void main() {
  Uint8List? pngMemo;

  /// PNG 编码走平台线程真实异步，须在 runAsync 内生成（测试间复用）
  Future<Uint8List> pngOf(WidgetTester tester) async =>
      pngMemo ??= (await tester.runAsync(() => png_bytes.solidPng()))!;

  Future<void> openSheet(
    WidgetTester tester, {
    required Future<void> Function(Uint8List)? onSave,
    required Future<void> Function(Uint8List)? onShare,
  }) async {
    final png = await pngOf(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: KazeTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                // 直接挂 LetterExportSheet 以注入回调（showLetterExportSheet
                // 是默认出口的固定壳）
                onPressed: () => showNatsuSheet(
                  context: context,
                  title: const Text('信已装成图'),
                  child: LetterExportSheet(
                    png: png,
                    onSave: onSave,
                    onShare: onShare,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// toast 的 2.4s 定时器走完，避免测试结束报 pending timer
  Future<void> flushToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('预览：长图与保存/分享按钮在位，无作者说明小字', (tester) async {
    await openSheet(tester, onSave: null, onShare: null);

    expect(find.text('信已装成图'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('保存到相册'), findsOneWidget);
    expect(find.text('分享给朋友'), findsOneWidget);
    expect(find.text('导出图不含任何作者信息'), findsNothing);
  });

  testWidgets('保存成功：回调收到字节，sheet 关闭', (tester) async {
    final saved = <Uint8List>[];
    await openSheet(
      tester,
      onSave: (bytes) async => saved.add(bytes),
      onShare: null,
    );

    await tester.tap(find.text('保存到相册'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(find.text('保存到相册'), findsNothing);
    expect(find.text('已存入相册'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('保存失败：toast 说明，sheet 留在原位可重试', (tester) async {
    await openSheet(
      tester,
      onSave: (_) async => throw StateError('denied'),
      onShare: null,
    );

    await tester.tap(find.text('保存到相册'));
    await tester.pumpAndSettle();

    expect(find.text('没能存入相册，检查相册权限后再试试'), findsOneWidget);
    expect(find.text('保存到相册'), findsOneWidget);
    await flushToast(tester);
  });

  testWidgets('分享：回调触发后 sheet 关闭', (tester) async {
    var shared = 0;
    await openSheet(tester, onSave: null, onShare: (_) async => shared++);

    await tester.tap(find.text('分享给朋友'));
    await tester.pumpAndSettle();

    expect(shared, 1);
    expect(find.text('分享给朋友'), findsNothing);
  });
}
