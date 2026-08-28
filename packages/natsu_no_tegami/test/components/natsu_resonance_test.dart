import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'NotoSansSC'),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('NatsuResonance.sentence', () {
    test('零计数不排「0 个」——它还在等第一个同感的人', () {
      expect(NatsuResonance.sentence(0), '它还在等第一个同感的人');
      expect(NatsuResonance.sentence(-1), '它还在等第一个同感的人');
    });

    test('正计数排成句子', () {
      expect(NatsuResonance.sentence(12), '12 个陌生人也曾有过这样的时刻');
      expect(NatsuResonance.sentence(1), '1 个陌生人也曾有过这样的时刻');
    });

    test('万位起缩写，尾零与点省略', () {
      expect(NatsuResonance.sentence(12345), contains('1.2万 个陌生人'));
      expect(NatsuResonance.sentence(20000), contains('2万 个陌生人'));
      expect(NatsuResonance.compactCount(12345678), '1234.6万');
      expect(NatsuResonance.compactCount(99999999), '10000万');
      // 亿位起换单位
      expect(NatsuResonance.compactCount(125000000), '1.3亿');
      expect(NatsuResonance.compactCount(2147483647), '21.5亿');
    });
  });

  group('NatsuResonance 三态', () {
    testWidgets('未共鸣：星形 inkSoft + 行动字 + 句子，tap 触发一次', (tester) async {
      var resonated = 0;
      await tester.pumpWidget(
        _wrap(NatsuResonance(count: 3, onResonate: () => resonated++)),
      );

      // ✦ 已是 Painter 描形（不再依赖字体度量），星形颜色直接从 painter 反解
      expect(
        find.descendant(
          of: find.byType(NatsuResonance),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      // 行动字与句子在同一个 Text.rich 段落里（基线由排版器统一）——
      // find.text 只匹配整段富文本，改用 textContaining
      expect(find.textContaining('共鸣'), findsOneWidget);
      expect(find.textContaining(NatsuResonance.sentence(3)), findsOneWidget);
      expect(_sparkleColor(tester), NatsuColors.inkSoft);

      await tester.tap(find.byType(NatsuResonance));
      await tester.pumpAndSettle();
      expect(resonated, 1);
    });

    testWidgets('已共鸣：星形 coralStamp、无行动字、tap 不再触发', (tester) async {
      var resonated = 0;
      await tester.pumpWidget(
        _wrap(
          NatsuResonance(
            count: 13,
            onResonate: () => resonated++,
            resonated: true,
          ),
        ),
      );

      expect(find.textContaining('共鸣'), findsNothing);
      expect(find.textContaining(NatsuResonance.sentence(13)), findsOneWidget);
      expect(_sparkleColor(tester), NatsuColors.coralStamp);

      // 一次性：即使回调仍在，共鸣后 tap 被忽略
      await tester.tap(find.byType(NatsuResonance), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(resonated, 0);
    });

    testWidgets('禁用（onResonate null）：✦/文字降级，句子仍显示', (tester) async {
      await tester.pumpWidget(
        _wrap(const NatsuResonance(count: 5, onResonate: null)),
      );

      expect(find.text(NatsuResonance.sentence(5)), findsOneWidget);
      expect(_sparkleColor(tester), NatsuColors.disabledContent);
      expect(_sentenceStyle(tester)!.color, NatsuColors.disabledContent);
    });

    testWidgets('落章动效：resonated false→true 触发 scale/rotation 与颜色渐变', (
      tester,
    ) async {
      var resonated = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => NatsuResonance(
              count: 3,
              resonated: resonated,
              onResonate: () => setState(() => resonated = true),
            ),
          ),
        ),
      );

      // 落章前 ✦ 静止（scale 1 / 0°）
      expect(_sparkleScale(tester), 1.0);

      await tester.tap(find.byType(NatsuResonance));
      await tester.pump(); // 落章起跳帧
      await tester.pump(const Duration(milliseconds: 100)); // 动画进行中
      final midScale = _sparkleScale(tester);
      expect(midScale, greaterThan(0.6));
      expect(midScale, lessThan(1.15));

      // 颜色在墨与珊瑚之间补间，不再是跳变
      final midColor = _sparkleColor(tester)!;
      expect(midColor, isNot(NatsuColors.inkSoft));
      expect(midColor, isNot(NatsuColors.coralStamp));

      await tester.pumpAndSettle();
      expect(_sparkleScale(tester), 1.0);
      // 落章后颜色变珊瑚
      expect(_sparkleColor(tester), NatsuColors.coralStamp);
    });

    testWidgets('挂载即已共鸣/true→true 重建都不重放落章', (tester) async {
      // 挂载时已是共鸣状态（读到一封自己此前共鸣过的信）——不放动画
      await tester.pumpWidget(
        _wrap(NatsuResonance(count: 13, onResonate: () {}, resonated: true)),
      );
      await tester.pump();
      expect(_sparkleScale(tester), 1.0);

      // 父层重建（count 变化，resonated 保持 true）——不重放
      await tester.pumpWidget(
        _wrap(NatsuResonance(count: 14, onResonate: () {}, resonated: true)),
      );
      await tester.pumpAndSettle();
      expect(_sparkleScale(tester), 1.0);
      expect(_sparkleColor(tester), NatsuColors.coralStamp);
    });

    testWidgets('计数校正：句子随 count 变化淡入换句不硬切', (tester) async {
      var count = 13;
      late StateSetter update;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, innerSetState) {
              update = innerSetState;
              return NatsuResonance(
                count: count,
                onResonate: () {},
                resonated: true,
              );
            },
          ),
        ),
      );
      // 服务端校正：乐观 14 → 真值 15，重建期间旧句与新句同屏淡变
      update(() => count = 15);
      await tester.pump();
      expect(find.byWidgetPredicate((w) => w is FadeTransition), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text(NatsuResonance.sentence(15)), findsOneWidget);
      expect(find.text(NatsuResonance.sentence(13)), findsNothing);
    });

    testWidgets('超大计数：配 FittedBox 兜底（底栏同款结构）不溢出', (tester) async {
      // 读信底栏同款约束：Expanded + FittedBox scaleDown——句子自然尺寸
      // 超宽时整体缩小，RenderFlex 不溢出不抛异常
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 320,
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: NatsuResonance(
                      count: 2147483647,
                      onResonate: () {},
                      resonated: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // 21 亿折成「21.5亿」，句子保持一屏可读
      expect(find.textContaining('21.5亿'), findsOneWidget);
    });
  });
}

/// 从星形 painter 反解当前颜色（_SparklePainter 是私有类，dynamic 取色）
Color? _sparkleColor(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(NatsuResonance),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.painter as dynamic).color as Color?;
}

/// 从 ScaleTransition 的动画反解当前 ✦ scale（限定在组件内，
/// MaterialApp 自身的结构也可能含 ScaleTransition）
double _sparkleScale(WidgetTester tester) {
  final scale = tester.widget<ScaleTransition>(
    find.descendant(
      of: find.byType(NatsuResonance),
      matching: find.byType(ScaleTransition),
    ),
  );
  return scale.scale.value;
}

TextStyle? _sentenceStyle(WidgetTester tester) {
  final text = tester.widget<Text>(find.textContaining('陌生人也曾有过这样的时刻'));
  return text.style;
}
