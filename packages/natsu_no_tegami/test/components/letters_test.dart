import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'NotoSansSC'),
  home: Scaffold(body: Center(child: child)),
);

/// 1x1 测试图片（避免资产缺失异常）
final ImageProvider _testImage = MemoryImage(
  Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  ]),
);

void main() {
  testWidgets('LetterPaper 渲染正文/meta/计数句', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LetterPaper(
          body: '末班电车的窗外，灯火像退潮一样流走。',
          place: '江の島',
          time: '2026.08.19 23:47',
          weather: '小雨',
          countLine: '已被 3 个陌生人拾起 ·',
        ),
      ),
    );
    expect(find.text('末班电车的窗外，灯火像退潮一样流走。'), findsOneWidget);
    expect(find.text('江の島 · 2026.08.19 23:47 · 小雨'), findsOneWidget);
    expect(find.text('已被 3 个陌生人拾起 ·'), findsOneWidget);
  });

  testWidgets('PhotoCard 倾斜 == 种子派生值（确定性）', (tester) async {
    const seed = 'photo-test-1';
    await tester.pumpWidget(
      _wrap(PhotoCard(image: _testImage, seedId: seed, caption: '七月的海')),
    );

    double rotationOf() {
      final t = tester.widget<Transform>(
        find.descendant(
          of: find.byType(PhotoCard),
          matching: find.byType(Transform),
        ),
      );
      // Matrix4 列主序：rotation 的 sin(angle) = storage[1]（row1, col0）
      return math.asin(t.transform.storage[1].clamp(-1.0, 1.0));
    }

    final actual = rotationOf();
    final expected = NatsuImperfection.tiltOf(seed) * math.pi / 180;
    expect(actual, closeTo(expected, 1e-6), reason: 'PhotoCard 倾斜应由种子确定性派生');

    // 同种子重建：角度不变
    await tester.pumpWidget(_wrap(PhotoCard(image: _testImage, seedId: seed)));
    expect(rotationOf(), closeTo(expected, 1e-6));
  });

  testWidgets('Postmark 双样式渲染（circular 地名弧排逐字）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Postmark(place: '鎌倉', date: '2026.08.19', weather: '晴'),
            SizedBox(height: NatsuSpacing.md),
            Postmark(
              place: '鎌倉',
              date: '2026.08.19',
              weather: '晴',
              style: NatsuPostmarkStyle.horizontal,
            ),
          ],
        ),
      ),
    );
    // circular：地名拆字沿弧排布 + 日期/天气分行居中
    expect(find.text('鎌'), findsOneWidget);
    expect(find.text('倉'), findsOneWidget);
    expect(find.text('2026.08.19'), findsOneWidget);
    expect(find.text('晴'), findsOneWidget);
    // horizontal：一行合并
    expect(find.text('鎌倉 · 2026.08.19 · 晴'), findsOneWidget);
  });

  testWidgets('Postmark 弧排地名永不截断：N 字渲染 N 个 Text', (tester) async {
    const longPlace = '鎌倉市片瀬江ノ島'; // 8 字，超出基准容量
    await tester.pumpWidget(
      _wrap(const Postmark(place: longPlace, date: '2026.08.19')),
    );
    for (final c in longPlace.characters) {
      expect(find.text(c), findsOneWidget, reason: '字「$c」应独立渲染在弧上');
    }
  });

  test('Postmark 弧排字号规则：容量内基准，超出递减，下限 10', () {
    expect(Postmark.arcPlaceFontSize(2), 13);
    expect(Postmark.arcPlaceFontSize(6), 13, reason: '容量内不缩');
    expect(Postmark.arcPlaceFontSize(7), 12);
    expect(Postmark.arcPlaceFontSize(8), 11);
    // 单调不增 + 下限
    var prev = Postmark.arcPlaceFontSize(1);
    for (var n = 2; n <= 16; n++) {
      final cur = Postmark.arcPlaceFontSize(n);
      expect(cur, lessThanOrEqualTo(prev), reason: '$n 字不应比 ${n - 1} 字大');
      expect(cur, greaterThanOrEqualTo(10), reason: '下限 10');
      prev = cur;
    }
  });

  testWidgets('Postmark size 参数：呈现尺寸 == size（viewBox 等比）', (tester) async {
    await tester.pumpWidget(
      _wrap(const Postmark(place: '鎌倉', date: '2026.08', size: 120)),
    );
    final sz = tester.getSize(find.byType(Postmark));
    expect(sz.width, closeTo(120, 0.1));
    expect(sz.height, closeTo(120, 0.1));
  });

  testWidgets('StampPiece 锯齿边与面值', (tester) async {
    await tester.pumpWidget(_wrap(const StampPiece(seedId: 'stamp-1')));
    expect(find.byType(ClipPath), findsOneWidget);
    expect(find.text('夏'), findsOneWidget);
  });

  testWidgets('StampPiece 比例锁 0.8：宽高恒定，宽可随意缩放', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Row(
          children: [
            StampPiece(seedId: 's1'),
            StampPiece(seedId: 's2', width: 40),
          ],
        ),
      ),
    );
    expect(StampPiece.aspectRatio, 0.8);

    final s64 = tester.getSize(
      find.byWidgetPredicate((w) => w is StampPiece && w.seedId == 's1'),
    );
    final s40 = tester.getSize(
      find.byWidgetPredicate((w) => w is StampPiece && w.seedId == 's2'),
    );
    // 布局尺寸 = 宽 × 宽/0.8（Transform 是绘制期的，布局上 ScaledDesign
    // 的 SizedBox 就是最终占位）
    expect(s64.width, closeTo(64, 0.1));
    expect(s64.height, closeTo(64 / 0.8, 0.1));
    expect(s40.width, closeTo(40, 0.1));
    expect(s40.height, closeTo(40 / 0.8, 0.1));
  });

  testWidgets('DeskScene 入场后全部可见', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DeskScene(
          height: 640,
          animateIn: true,
          children: [
            const Positioned(
              left: 20,
              top: 20,
              child: StampPiece(seedId: 'd1'),
            ),
            const Positioned(
              left: 120,
              top: 40,
              child: Postmark(place: '江の島', date: '2026.08'),
            ),
            Positioned(
              left: 40,
              top: 180,
              width: 400,
              child: LetterPaper(body: '机の上の手紙。', place: '東京'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('机の上の手紙。'), findsOneWidget);
    expect(find.text('東京'), findsOneWidget);
    expect(find.byType(StampPiece), findsOneWidget);
  });
}
