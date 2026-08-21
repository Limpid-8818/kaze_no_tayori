import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'NotoSansSC'),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('NatsuButton', () {
    testWidgets('四变体渲染且可点击', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NatsuButton(
                variant: NatsuButtonVariant.primary,
                onPressed: () => tapped++,
                child: const Text('投递出去'),
              ),
              NatsuButton(
                variant: NatsuButtonVariant.secondary,
                onPressed: () {},
                child: const Text('留在这里'),
              ),
              NatsuButton(
                variant: NatsuButtonVariant.ghost,
                onPressed: () {},
                child: const Text('继续旅行'),
              ),
              NatsuButton(
                variant: NatsuButtonVariant.destructive,
                onPressed: () {},
                child: const Text('举报'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('投递出去'), findsOneWidget);
      expect(find.text('留在这里'), findsOneWidget);
      await tester.tap(find.text('投递出去'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('禁用态不响应点击', (tester) async {
      await tester.pumpWidget(
        _wrap(const NatsuButton(onPressed: null, child: Text('禁用'))),
      );
      expect(find.text('禁用'), findsOneWidget);
      await tester.tap(find.text('禁用'));
      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .decoration,
        isA<BoxDecoration>(),
      );
    });
  });

  group('NatsuTag', () {
    testWidgets('常规与选中态', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NatsuTag(label: '夜の電車', dot: NatsuColors.skyBlue),
              NatsuTag(label: '海', selected: true),
              NatsuTag(label: '夕立', size: NatsuTagSize.sm),
            ],
          ),
        ),
      );
      expect(find.text('夜の電車'), findsOneWidget);
      expect(find.text('海'), findsOneWidget);
      expect(find.text('夕立'), findsOneWidget);
    });
  });

  group('NatsuInput', () {
    testWidgets('输入与计数', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          NatsuInput(controller: controller, hint: '写点什么…', maxLength: 800),
        ),
      );
      await tester.enterText(find.byType(TextField), 'まだ遠くへ');
      await tester.pump();
      expect(find.text('5 / 800'), findsOneWidget);
      controller.dispose();
    });
  });

  group('NatsuCard / NatsuQuote / NatsuSeal / MetaLine', () {
    testWidgets('组合渲染', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NatsuCard(
            surface: NatsuCardSurface.envelope,
            stamp: const NatsuSeal(character: '夏', size: 40),
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NatsuMetaLine(items: ['江の島', '23:47', '小雨']),
                const SizedBox(height: NatsuSpacing.md),
                const NatsuQuote(
                  text: 'まだ遠くへ、海の方へ。',
                  source: '《老人と海》',
                  kind: NatsuQuoteKind.music,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('江の島 · 23:47 · 小雨'), findsOneWidget);
      expect(find.text('まだ遠くへ、海の方へ。'), findsOneWidget);
      expect(find.text('♪ 《老人と海》'), findsOneWidget);
      expect(find.text('夏'), findsOneWidget);
    });
  });

  group('NatsuSwitch', () {
    testWidgets('点击触发 onChanged 且轨道色 off→on', (tester) async {
      var value = false;
      await tester.pumpWidget(
        _wrap(NatsuSwitch(value: value, onChanged: (v) => value = v)),
      );

      // 初始轨道 = 纸缘灰
      expect(_switchTrackColor(tester), NatsuColors.paperEdge);
      await tester.tap(find.byType(NatsuSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);

      // 重渲染为开 → 夏空蓝（被光照到）
      await tester.pumpWidget(
        _wrap(NatsuSwitch(value: value, onChanged: (v) => value = v)),
      );
      await tester.pumpAndSettle();
      expect(_switchTrackColor(tester), NatsuColors.skyBlue);
    });

    testWidgets('禁用不触发', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          NatsuSwitch(
            value: false,
            onChanged: (v) => fired = true,
            enabled: false,
          ),
        ),
      );
      await tester.tap(find.byType(NatsuSwitch), warnIfMissed: false);
      expect(fired, isFalse);
    });
  });

  group('NatsuCheckbox', () {
    testWidgets('点击 false→true，选中块 = 夏空蓝 + 勾存在', (tester) async {
      var value = false;
      await tester.pumpWidget(
        _wrap(
          NatsuCheckbox(value: value, onChanged: (v) => value = v ?? false),
        ),
      );
      await tester.tap(find.byType(NatsuCheckbox));
      await tester.pumpAndSettle();
      expect(value, isTrue);

      await tester.pumpWidget(
        _wrap(
          NatsuCheckbox(value: value, onChanged: (v) => value = v ?? false),
        ),
      );
      await tester.pumpAndSettle();
      final box = _checkboxDecoration(tester);
      expect(box.color, NatsuColors.skyBlue);
      expect(
        find.descendant(
          of: find.byType(NatsuCheckbox),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('禁用不触发', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          NatsuCheckbox(
            value: false,
            onChanged: (v) => fired = true,
            enabled: false,
          ),
        ),
      );
      await tester.tap(find.byType(NatsuCheckbox), warnIfMissed: false);
      expect(fired, isFalse);
    });
  });

  group('NatsuRadio', () {
    testWidgets('点击第二项回调其值', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NatsuRadio<String>(
                value: 'yoru',
                groupValue: null,
                onChanged: (v) => picked = v,
              ),
              NatsuRadio<String>(
                value: 'asa',
                groupValue: null,
                onChanged: (v) => picked = v,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(NatsuRadio<String>).last);
      await tester.pumpAndSettle();
      expect(picked, 'asa');
    });

    testWidgets('选中态内点 = 夏空蓝', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NatsuRadio<String>(value: 'a', groupValue: 'a', onChanged: (v) {}),
        ),
      );
      await tester.pumpAndSettle();
      final dot = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(dot.scale, 1);
      // 内点容器色
      final decorated =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(AnimatedScale),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decorated.color, NatsuColors.skyBlue);
    });
  });

  group('NatsuSlider', () {
    testWidgets('初始旋钮位置反解 == 2f-1，拖动更新值', (tester) async {
      var value = 0.25;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 320,
              child: NatsuSlider(
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 反解旋钮 Align（fraction 0.25 → alignment.x = -0.5）
      final knobs = find.descendant(
        of: find.byType(NatsuSlider),
        matching: find.byType(Align),
      );
      // _Track 内有活跃段 Align + 旋钮 Align，取最后一个（旋钮）
      final align = tester.widget<Align>(knobs.last);
      expect((align.alignment as Alignment).x, closeTo(-0.5, 0.001));

      // 点按轨道末端 → 值变大
      await tester.tap(find.byType(NatsuSlider));
      await tester.pumpAndSettle();
      expect(value, greaterThan(0.25));
    });

    testWidgets('禁用无响应', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 320,
            child: NatsuSlider(
              value: 0.5,
              onChanged: (v) => fired = true,
              enabled: false,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(NatsuSlider), warnIfMissed: false);
      expect(fired, isFalse);
    });
  });

  group('NatsuProgress', () {
    testWidgets('determinate：宽度因子 == value', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(width: 320, child: NatsuProgress(value: 0.62))),
      );
      await tester.pumpAndSettle();
      final box = tester.widget<AnimatedFractionallySizedBox>(
        find.byType(AnimatedFractionallySizedBox),
      );
      expect(box.widthFactor, 0.62);
    });

    testWidgets('indeterminate：只 pump 有限时长（禁止 pumpAndSettle）', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(width: 320, child: NatsuProgress())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(NatsuProgress), findsOneWidget);
    });
  });

  group('NatsuSpinner', () {
    testWidgets('渲染邮戳环且 dispose 无错', (tester) async {
      await tester.pumpWidget(_wrap(const NatsuSpinner()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(NatsuSpinner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NatsuSpinner),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });
  });

  group('showNatsuDialog', () {
    testWidgets('弹出/遮罩色/scrim 点击关闭', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => NatsuButton(
                onPressed: () => showNatsuDialog(
                  context: context,
                  title: const Text('把信寄出去吗？'),
                  body: const Text('寄出后它将匿名漂流。'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('把信寄出去吗？'), findsOneWidget);
      // scrim 遮罩存在且为有色 barrier（Navigator 根 barrier 无色不参与）
      expect(find.byType(AnimatedModalBarrier), findsOneWidget);

      // 纪律：浮层内文本不得继承 debug 回退样式的装饰（红字黄双下划线
      // 经 DefaultTextStyle merge 泄漏）——查 RenderParagraph 的生效样式
      final effective = tester
          .renderObject<RenderParagraph>(find.text('把信寄出去吗？'))
          .text
          .style!;
      expect(effective.decoration, isNull);
      expect(effective.color, NatsuColors.inkBlue);

      // 点遮罩关闭
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('把信寄出去吗？'), findsNothing);
    });
  });

  group('showNatsuSheet', () {
    testWidgets('把手存在 + barrier 可关', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => NatsuButton(
                onPressed: () => showNatsuSheet(
                  context: context,
                  title: const Text('让它怎么旅行？'),
                  child: const Text('内容'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('让它怎么旅行？'), findsOneWidget);

      // 拖拽把手：36×4 纸缘药丸（按精确尺寸定位）
      final handleBox = tester.renderObject<RenderBox>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints ==
                  const BoxConstraints.tightFor(width: 36, height: 4),
        ),
      );
      expect(handleBox.size.width, NatsuSpacing.handleW);
      expect(handleBox.size.height, NatsuSpacing.handleH);

      // 点遮罩关闭
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('让它怎么旅行？'), findsNothing);
    });
  });

  group('showNatsuToast', () {
    testWidgets('出现 → 停留 → 自动消失', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => NatsuButton(
                onPressed: () => showNatsuToast(context, '已共鸣'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(); // 入场开始
      await tester.pumpAndSettle(); // 入场完成（停留 Timer 仍挂起）
      expect(find.text('已共鸣'), findsOneWidget);

      // 停留期满 + 退场
      await tester.pump(NatsuMotion.toastDuration);
      await tester.pumpAndSettle();
      expect(find.text('已共鸣'), findsNothing);
    });
  });
}

/// 从 Switch 树中反解轨道 AnimatedContainer 的填充色
Color? _switchTrackColor(WidgetTester tester) {
  final track = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(NatsuSwitch),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return (track.decoration as BoxDecoration).color;
}

/// 从 Checkbox 树中反解方块 decoration（TweenAnimationBuilder 内的 Container）
BoxDecoration _checkboxDecoration(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(NatsuCheckbox),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            (w.constraints ?? const BoxConstraints()).maxWidth ==
                NatsuSpacing.checkSize,
      ),
    ),
  );
  return box.decoration as BoxDecoration;
}
