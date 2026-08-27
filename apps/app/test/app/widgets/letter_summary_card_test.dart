/// 信件摘要卡组件测试：俳句三行排版、第四行截断省略、无诗回退预览、
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
  testWidgets('有诗：俳句逐行衬线排版', (tester) async {
    await tester.pumpWidget(
      _host(
        const LetterSummaryCard(
          poem: '风穿过堤岸\n把下午吹得很轻\n浪只说了一半',
          timeLabel: '2小时前',
        ),
      ),
    );

    expect(find.text('风穿过堤岸'), findsOneWidget);
    expect(find.text('把下午吹得很轻'), findsOneWidget);
    expect(find.text('浪只说了一半'), findsOneWidget);
  });

  testWidgets('超过三行：只显示三行，末行以中文省略号收尾', (tester) async {
    await tester.pumpWidget(
      _host(const LetterSummaryCard(poem: '一行\n两行\n三行\n四行', timeLabel: '刚刚')),
    );

    expect(find.text('一行'), findsOneWidget);
    expect(find.text('三行……'), findsOneWidget);
    expect(find.text('四行'), findsNothing);
  });

  testWidgets('无诗：回退正文预览两行位（单条文本，超出折断省略）', (tester) async {
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

    await tester.tap(find.text('上海 · 武康路'));
    expect(tapped, isTrue);
  });
}
