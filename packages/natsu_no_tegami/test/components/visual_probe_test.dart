// ignore_for_file: avoid_print
// 视觉探针 — 手工调试用（flutter test test/components/visual_probe_test.dart）。
// 加载真实字体后把组件渲染成 PNG 写到 build/visual_probe/，供人眼检查
// 字体基线/布局；不参与 CI 断言（全部 expect 恒真）。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

Future<void> _loadFonts() async {
  // widget 测试默认 Ahem 方块字体，且 rootBundle 在测试环境为空——
  // 必须直接读磁盘字体文件加载真实字体才能看基线。
  // 组件令牌 TextStyle 带 package: 前缀，引擎按
  // `packages/natsu_no_tegami/<family>` 查找——两种名都注册。
  final fonts = [
    ('NotoSansSC', 'assets/fonts/info/NotoSansSC-Variable.ttf'),
    ('LXGWWenKai', 'assets/fonts/warm/LXGWWenKai-Regular.ttf'),
    ('NotoSansJP', 'assets/fonts/info/NotoSansJP-Variable.ttf'),
    ('KleeOne', 'assets/fonts/warm/KleeOne-Regular.ttf'),
    ('Inter', 'assets/fonts/info/Inter-Regular.ttf'),
  ];
  for (final (family, path) in fonts) {
    final bytes = await File(path).readAsBytes();
    for (final name in [family, 'packages/natsu_no_tegami/$family']) {
      final loader = FontLoader(name)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  }
}

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  // toImage/toByteData 的 PNG 编码走真实异步（平台线程），必须 runAsync
  // 放出 FakeAsync 区，否则测试永久挂起（同 letter_export_test 的坑）
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final dir = Directory('build/visual_probe');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png').writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  });
}

Future<void> _pumpScene(
  WidgetTester tester,
  Widget child,
  GlobalKey key,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansSC'),
      home: Scaffold(
        backgroundColor: NatsuColors.paperWhite,
        body: Center(
          child: RepaintBoundary(key: key, child: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('视觉探针: 共鸣组件各态', (tester) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await _pumpScene(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 未共鸣（行动字 + 句子）
          NatsuResonance(count: 3, onResonate: () {}),
          const SizedBox(height: 24),
          // 已共鸣（✦ + 句子）
          const NatsuResonance(count: 13, resonated: true, onResonate: _noop),
          const SizedBox(height: 24),
          // 禁用
          const NatsuResonance(count: 5, onResonate: null),
        ],
      ),
      key,
    );
    await _save(tester, key, 'resonance_fixed_r2');
    expect(true, isTrue);
  });

  testWidgets('视觉探针: 封筒宛名各字数（单列缩字 / 满列分列）', (tester) async {
    tester.view.physicalSize = const Size(1500, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const names = [
      '風の旅人', // 4 字：28 号不变
      '银河的邮递员', // 6 字：单列缩字
      '夏蝉与风铃的信箱', // 8 字：单列缩字
      '银河邮递员与季风信使', // 10 字：5+5 满列双列
      '夏风把信笺吹向远方的山谷与海', // 14 字：双列
      '夏风把这一封信笺吹向了远方的山谷与海之', // 19 字：三列
      'ああああああああああああああああああああああああああああああああ', // 32 字：四列
    ];
    final key = GlobalKey();
    await _pumpScene(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final (i, name) in names.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Envelope(
                    seedId: 'probe-addr-$i',
                    addressee: name,
                    place: '鎌倉',
                    date: '2026.08.21',
                    width: 130,
                    tilt: 0,
                  ),
                  const SizedBox(height: 8),
                  Text('${name.length}字', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      key,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _save(tester, key, 'envelope_addressee');
    expect(true, isTrue);
  });

  testWidgets('视觉探针: 导出对话框（真实信纸比例 + 笔记本视口）', (tester) async {
    // 常规笔记本视口（此前 1500 高视口不复现溢出——真实场景图更高屏更矮）
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 造一张真实比例的「信纸截图」：560 宽四段图文流 → 高约 1400。
    // 修复后的对话框结构：ConstrainedBox(maxHeight 55% 视口) + Flexible 图
    final letterPng = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint();
      paint.shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(0, 1400),
        [NatsuColors.skyTop, NatsuColors.skyHorizon],
      );
      canvas.drawRect(const Rect.fromLTWH(0, 0, 560, 1400), paint);
      final para =
          ui.ParagraphBuilder(
            ui.ParagraphStyle(fontSize: 20, fontFamily: 'LXGWWenKai'),
          )..addText(
            '给不知在何处的你：\n今天在海边坐了一下午。风把云吹得很慢，'
            '慢到可以数清每一朵的边缘。\n\n回去的电车上，灯火像退潮一样流走。'
            '我想，这大概就是夏天——光太多，装不下，只好溢出来。\n\n海辺にて',
          );
      canvas.drawParagraph(
        para.build()..layout(const ui.ParagraphConstraints(width: 480)),
        const Offset(40, 44),
      );
      final pic = recorder.endRecording();
      final image = await pic.toImage(560, 1400);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    }))!;

    final key = GlobalKey();
    await _pumpScene(
      tester,
      NatsuDialog(
        title: const Text('匿名导出'),
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: 800 * 0.55, // 同 letter_section 修复：视口 55%
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(NatsuRadius.card),
                  child: Image.memory(
                    letterPng,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              const SizedBox(height: NatsuSpacing.md),
              const Text(
                '导出为匿名图片 · 不含作者信息 · 由你自行保存',
                style: NatsuTypography.bodySecondary,
              ),
            ],
          ),
        ),
        actions: [
          NatsuButton(
            variant: NatsuButtonVariant.ghost,
            size: NatsuButtonSize.sm,
            onPressed: () {},
            child: const Text('閉じる'),
          ),
        ],
      ),
      key,
    );
    await _save(tester, key, 'export_dialog_fixed_r2');
    expect(true, isTrue);
  });
}

void _noop() {}
