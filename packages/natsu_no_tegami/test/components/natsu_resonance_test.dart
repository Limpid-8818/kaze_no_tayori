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
  });

  group('NatsuResonance 三态', () {
    testWidgets('未共鸣：✦ inkSoft + 行动字 + 句子，tap 触发一次', (tester) async {
      var resonated = 0;
      await tester.pumpWidget(
        _wrap(NatsuResonance(count: 3, onResonate: () => resonated++)),
      );

      expect(find.text('✦'), findsOneWidget);
      // 行动字与句子在同一个 Text.rich 段落里（基线由排版器统一）——
      // find.text 只匹配整段富文本，改用 textContaining
      expect(find.textContaining('共鸣'), findsOneWidget);
      expect(find.textContaining(NatsuResonance.sentence(3)), findsOneWidget);
      expect(_sparkleColor(tester), NatsuColors.inkSoft);

      await tester.tap(find.byType(NatsuResonance));
      await tester.pumpAndSettle();
      expect(resonated, 1);
    });

    testWidgets('已共鸣：✦ coralStamp、无行动字、tap 不再触发', (tester) async {
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

    testWidgets('落章动效：resonated false→true 触发 scale/rotation 动画', (
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
      await tester.pump();
      expect(_sparkleScale(tester), 1.0);
      expect(_sparkleColor(tester), NatsuColors.coralStamp);
    });
  });
}

/// 从 widget 树反解 ✦ 的颜色
Color? _sparkleColor(WidgetTester tester) {
  final sparkle = tester.widget<Text>(find.text('✦'));
  return sparkle.style?.color;
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
