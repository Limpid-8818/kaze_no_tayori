/// 导出画布构图测试：天色背景与读信页同源、信纸复用 LetterReading、
/// 右下角 logo + 「风信」水印在位。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/features/reader/letter_view.dart';
import 'package:kazenotayori/features/reader/widgets/letter_export_canvas.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

/// 纯文本信：resolver 不应被调用（一调用即测试失败）
ImageProvider fakeResolver(String ref) => throw StateError('unexpected: $ref');

LetterView _view({String? weatherIcon}) => LetterView(
  id: 'letter_1',
  blocks: const [TextBlock('傍晚的海边风很大')],
  createdAt: DateTime(2026, 8, 26, 10), // 本地 10 点 → 朝
  signature: '赶海的人',
  place: '浙江 · 舟山',
  weatherText: '多云',
  weatherIcon: weatherIcon,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: KazeTheme.light(),
  home: Scaffold(body: child),
);

/// 天空底容器：全树唯一「带渐变」的 BoxDecoration
Finder _skyContainer() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).gradient != null,
);

void main() {
  testWidgets('构图：信纸复用 LetterReading、正文/署名/meta 齐全、右下水印在位', (tester) async {
    final view = _view();
    await tester.pumpWidget(
      _wrap(
        LetterExportCanvas(
          blocks: view.blocks,
          photoResolver: fakeResolver,
          seedId: view.id,
          place: view.place,
          time: view.timeLabel,
          dayPeriod: view.dayPeriod,
          weather: view.weatherText,
          signature: view.signature,
          skyGradient: skyOfLetter(view),
        ),
      ),
    );
    await tester.pump();

    expect(_skyContainer(), findsOneWidget);
    expect(find.byType(LetterReading), findsOneWidget);
    expect(find.text('傍晚的海边风很大'), findsOneWidget);
    expect(find.text('赶海的人'), findsOneWidget);
    // meta 行：地点 · 日期 · 时段 · 天气（同一行内以「 · 」连接）
    expect(find.text('浙江 · 舟山 · 8月26日 · 朝 · 多云'), findsOneWidget);
    // 水印：logo 图 + 「风信」
    expect(find.text('风信'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/images/app_logo.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('watermark=false：不渲染水印', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LetterExportCanvas(
          blocks: _view().blocks,
          photoResolver: fakeResolver,
          watermark: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('风信'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('天色与读信页同源：导出画布渐变 === skyOfLetter 的预设实例', (tester) async {
    // 雨 × 朝 → morningRainy 档；带天气的信不吃默认昼·晴
    final view = _view(weatherIcon: 'rainy');
    final expected = skyOfLetter(view);

    await tester.pumpWidget(
      _wrap(
        LetterExportCanvas(
          blocks: view.blocks,
          photoResolver: fakeResolver,
          skyGradient: expected,
        ),
      ),
    );
    await tester.pump();

    final decoration =
        tester.widget<Container>(_skyContainer()).decoration! as BoxDecoration;
    expect(decoration.gradient, same(NatsuWeatherLight.morningRainy.gradient));
  });

  test('skyOfLetter：没带天气回退默认昼·晴', () {
    expect(skyOfLetter(null), same(KazeSky.defaultGradient));
    expect(
      skyOfLetter(_view(weatherIcon: null)),
      same(KazeSky.defaultGradient),
    );
  });

  test('skyOfLetter：天气 × 落笔时段查表（夜档用落笔时刻而非当前时间）', () {
    final nightLetter = LetterView(
      id: 'letter_n',
      blocks: const [TextBlock('夜里的信')],
      createdAt: DateTime(2026, 8, 26, 23),
      weatherIcon: 'sunny',
    );
    expect(
      skyOfLetter(nightLetter),
      same(NatsuWeatherLight.nightSunny.gradient),
    );
  });
}
