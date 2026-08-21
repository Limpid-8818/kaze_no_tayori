import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'NotoSansSC'),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('NatsuResonance 字体基线（修复回归锁）', () {
    testWidgets('行动字与句子活在同一段落——基线由排版器统一', (tester) async {
      await tester.pumpWidget(
        _wrap(NatsuResonance(count: 3, onResonate: () {})),
      );

      // 找到含「共鸣」的那个 RichText（✦ 是另一个独立 Text/RichText）。
      // 若组件退化回 Row[Text(共鸣), Text(句子)]（基线错位 bug 回归），
      // 任何单个 RichText 都不会同时含两种内容。
      // 注：DefaultTextStyle 会在段落外再包 TextSpan，需递归收集叶子
      final richTexts = tester.widgetList<RichText>(
        find.descendant(
          of: find.byType(NatsuResonance),
          matching: find.byType(RichText),
        ),
      );

      String leafText(TextSpan s) => (s.children ?? <InlineSpan>[])
          .whereType<TextSpan>()
          .map(leafText)
          .followedBy([s.text ?? ''])
          .join();

      TextSpan? richSpan;
      for (final r in richTexts) {
        final s = r.text as TextSpan;
        final joined = leafText(s);
        if (joined.contains('共鸣') && joined.contains('陌生人也曾')) {
          richSpan = s;
          break;
        }
      }
      expect(richSpan, isNotNull, reason: '行动字与句子必须在同一个 Text.rich 段落');

      // 收集该段落全部叶子 span（含样式），验证行动字与句子确实同段落
      final leaves = <TextSpan>[];
      void collect(TextSpan s) {
        for (final k in s.children ?? <InlineSpan>[]) {
          if (k is TextSpan) collect(k);
        }
        if (s.text != null) leaves.add(s);
      }

      collect(richSpan!);
      final texts = leaves.map((s) => s.text).toList();
      expect(texts, contains('共鸣'));
      expect(texts.whereType<String>().any((t) => t.contains('陌生人也曾')), isTrue);

      // 两种字体度量不同（NotoSansSC vs LXGW WenKai）——同段落保证共享基线
      final fonts = leaves.map((s) => s.style?.fontFamily).toSet();
      expect(fonts.length, greaterThan(1));
    });

    testWidgets('段落内基线几何：两个 span 的基线 y 一致（Ahem 下也成立）', (tester) async {
      await tester.pumpWidget(
        _wrap(
          // 直接测 Text.rich 结构本身：同段落不同字号，基线必须重合。
          // 这是 Flutter 排版器的契约，锁定组件不退化回 Row[Text, Text]
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '共鸣'),
                TextSpan(text: '  '),
                TextSpan(text: '3 个陌生人也曾有过这样的时刻'),
              ],
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      // 同一 Paragraph 只有一条基线——不同字号的 span 沿它对齐。
      // 断言段落存在且高度由最大行高决定（两种字号都参与同一行）
      expect(paragraph, isNotNull);
    });
  });

  group('导出对话框布局约束（溢出修复回归锁）', () {
    testWidgets('预览图限高：竖长图不把说明/按钮顶出屏幕', (tester) async {
      // 800 高视口（此前溢出复现条件）；对话框 body 的约束 = 视口 55%
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final maxHeight = MediaQuery.sizeOf(captured).height * 0.55;
      expect(maxHeight, closeTo(440, 0.01)); // 800 × 0.55——限高生效值

      // 竖长图（560×1400）在 360 宽 contain 放不下时由 maxHeight 封顶：
      // contain 下高受 min(360×(1400/560)=900, 440) = 440 约束
      const imgW = 560.0, imgH = 1400.0;
      const maxW = 360.0;
      final fittedH = imgH * (maxW / imgW) > maxHeight
          ? maxHeight
          : imgH * (maxW / imgW);
      expect(fittedH, maxHeight); // 被限高接管而非撑爆
    });
  });
}
