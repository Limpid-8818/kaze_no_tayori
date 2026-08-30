/// 信件摘要卡组件测试：正文预览主位 + 诗注记单行灰字、无诗仅预览、
/// 距离/地点槽与时间、点击回调。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/app/widgets/letter_summary_card.dart';

Widget _host(Widget card) {
  return MaterialApp(
    theme: KazeTheme.light(),
    home: Scaffold(body: ListView(children: [card])),
  );
}

void main() {
  testWidgets('有诗：预览与诗注记双段并存，三行诗压成一行空格分隔', (tester) async {
    await tester.pumpWidget(
      _host(
        const LetterSummaryCard(
          previewText: '风从梧桐树叶间穿过的时候，整条街都在轻轻摇晃。',
          poem: '风穿过堤岸\n把下午吹得很轻\n浪只说了一半',
          timeLabel: '2小时前',
        ),
      ),
    );

    expect(find.text('风从梧桐树叶间穿过的时候，整条街都在轻轻摇晃。'), findsOneWidget);
    final note = tester.widget<Text>(find.text('风穿过堤岸 把下午吹得很轻 浪只说了一半'));
    expect(note.maxLines, 1);
    expect(note.style?.color, KazeColors.inkFaint);
    expect(note.style?.fontSize, 12);
  });

  testWidgets('超过三行：同样压一行，整体单行省略不换行', (tester) async {
    await tester.pumpWidget(
      _host(
        const LetterSummaryCard(
          previewText: '正文开头。',
          poem: '一行\n两行\n三行\n四行',
          timeLabel: '刚刚',
        ),
      ),
    );

    final note = tester.widget<Text>(find.text('一行 两行 三行 四行'));
    expect(note.maxLines, 1);
    expect(note.overflow, TextOverflow.ellipsis);
  });

  testWidgets('无诗：仅正文预览两行位（单条文本，超出折断省略）', (tester) async {
    await tester.pumpWidget(
      _host(
        const LetterSummaryCard(
          previewText: '风从梧桐树叶间穿过的时候，整条街都在轻轻摇晃。',
          timeLabel: '3天前',
        ),
      ),
    );

    expect(find.text('风从梧桐树叶间穿过的时候，整条街都在轻轻摇晃。'), findsOneWidget);
  });

  testWidgets('meta 行：距离+地点并列，时间靠右；点击回调触发', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        LetterSummaryCard(
          placeLabel: '上海 · 武康路',
          distanceLabel: '230m',
          timeLabel: '3天前',
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('230m'), findsOneWidget);
    expect(find.text('上海 · 武康路'), findsOneWidget);
    expect(find.text('3天前'), findsOneWidget);

    // 距离以「地点 · 距离」接在地点灰字右边：x 坐标必须大于地点文本，
    // 且不再出现定位图标（同排统一灰字，靠「·」分隔）。
    final placeX = tester.getTopLeft(find.text('上海 · 武康路')).dx;
    final distanceX = tester.getTopLeft(find.text('230m')).dx;
    expect(distanceX, greaterThan(placeX));
    expect(find.byIcon(Icons.my_location), findsNothing);

    await tester.tap(find.text('上海 · 武康路'));
    expect(tapped, isTrue);
  });
}
