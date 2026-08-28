import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'NotoSansSC'),
  home: Scaffold(body: Center(child: child)),
);

int _columnCount(WidgetTester tester) => tester
    .widgetList<Column>(
      find.descendant(
        of: find.byType(VerticalHandwriting),
        matching: find.byType(Column),
      ),
    )
    .length;

double? _fontSizeOf(WidgetTester tester, String glyph) => tester
    .widget<Text>(
      // 重复字（如 32×「あ」）会命中多个 Text，取首个即可——同块同字号
      find
          .descendant(
            of: find.byType(VerticalHandwriting),
            matching: find.text(glyph),
          )
          .first,
    )
    .style
    ?.fontSize;

void main() {
  testWidgets('5 字以内：单列 28 号不变（回归）', (tester) async {
    await tester.pumpWidget(
      _wrap(const VerticalHandwriting(text: '風の旅人よ', maxHeight: 190)),
    );
    expect(_columnCount(tester), 1);
    expect(_fontSizeOf(tester, '風'), 28.0);
  });

  testWidgets('无 maxHeight：维持单列原样不缩字（现状回归）', (tester) async {
    await tester.pumpWidget(
      _wrap(const VerticalHandwriting(text: '银河邮递员与季风信使')),
    );
    expect(_columnCount(tester), 1);
    expect(_fontSizeOf(tester, '银'), 28.0);
  });

  testWidgets('6~9 字：单列渐缩不拆列，长名字号更小', (tester) async {
    await tester.pumpWidget(
      _wrap(const VerticalHandwriting(text: '银河的邮递员', maxHeight: 190)), // 6 字
    );
    expect(_columnCount(tester), 1);
    final six = _fontSizeOf(tester, '银')!;
    expect(six, lessThan(28));
    expect(six, closeTo(25.6, 0.2));

    await tester.pumpWidget(
      _wrap(
        const VerticalHandwriting(text: '北国海滨的风之信使', maxHeight: 190),
      ), // 9 字
    );
    expect(_columnCount(tester), 1);
    final nine = _fontSizeOf(tester, '北')!;
    expect(nine, closeTo(16.8, 0.2));
    expect(nine, lessThan(six), reason: '字越多单列字号应越小');
  });

  testWidgets('10 字：满列平衡 5+5 双列，28 号不缩（纵书正统）', (tester) async {
    await tester.pumpWidget(
      _wrap(const VerticalHandwriting(text: '银河邮递员与季风信使', maxHeight: 190)),
    );
    expect(_columnCount(tester), 2);
    expect(_fontSizeOf(tester, '银'), 28.0);

    // 阅读顺序第一列「银河邮递员」在最右，两列各 5 字满列
    final rightCol = find.ancestor(
      of: find.text('银'),
      matching: find.byType(Column),
    );
    expect(
      tester.widgetList<Text>(
        find.descendant(of: rightCol, matching: find.byType(Text)),
      ),
      hasLength(5),
    );
    final leftCol = find.ancestor(
      of: find.text('使'),
      matching: find.byType(Column),
    );
    expect(
      tester.widgetList<Text>(
        find.descendant(of: leftCol, matching: find.byType(Text)),
      ),
      hasLength(5),
    );
  });

  testWidgets('19 字：三列平衡，满列字号反超塞单列的 9 字', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const VerticalHandwriting(
          text: '夏风把这一封信笺吹向了远方的山谷与海之', // 19 字
          maxHeight: 190,
        ),
      ),
    );
    expect(_columnCount(tester), 3);
    expect(_fontSizeOf(tester, '夏'), closeTo(21.8, 0.2));
    expect(_fontSizeOf(tester, '夏'), greaterThan(16.8), reason: '满列分列比硬塞单列可读');
  });

  testWidgets('32 字：四列且整块不超宽度预算', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const VerticalHandwriting(
          text: 'ああああああああああああああああああああああああああああああああ', // 32 字
          maxHeight: 190,
          maxWidth: 140,
        ),
      ),
    );
    expect(_columnCount(tester), 4);
    expect(_fontSizeOf(tester, 'あ'), closeTo(19.0, 0.2));
    expect(
      tester.getSize(find.byType(VerticalHandwriting)).width,
      lessThanOrEqualTo(140),
      reason: '超长宛名不画出筒宽预算',
    );
  });

  testWidgets('maxWidth 兜底：双列超预算时整体缩字号', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const VerticalHandwriting(
          text: '银河邮递员与季风信使',
          maxHeight: 190,
          maxWidth: 50,
        ),
      ),
    );
    expect(_columnCount(tester), 2);
    expect(
      tester.getSize(find.byType(VerticalHandwriting)).width,
      closeTo(50, 0.5),
    );
  });

  testWidgets('空文本：不渲染也不抛异常', (tester) async {
    await tester.pumpWidget(
      _wrap(const VerticalHandwriting(text: '', maxHeight: 190)),
    );
    expect(
      find.descendant(
        of: find.byType(VerticalHandwriting),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
