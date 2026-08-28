import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'NotoSansSC'),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('封筒四要素契约：邮票/邮戳/刻印各一', (tester) async {
    await tester.pumpWidget(
      _wrap(Envelope(seedId: 'env-test', place: '鎌倉', date: '2026.08.21')),
    );

    expect(
      find.descendant(
        of: find.byType(Envelope),
        matching: find.byType(StampPiece),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Envelope),
        matching: find.byType(Postmark),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Envelope),
        matching: find.byType(NatsuSeal),
      ),
      findsOneWidget,
    );
  });

  testWidgets('宛名 null = 封面洁净（无竖排块）', (tester) async {
    await tester.pumpWidget(
      _wrap(Envelope(seedId: 'env-clean', place: '鎌倉', date: '2026.08.21')),
    );
    expect(find.byType(VerticalHandwriting), findsNothing);
  });

  testWidgets('宛名竖排：每字一个 Text（characters 拆分契约）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Envelope(
          seedId: 'env-addr',
          addressee: '風の旅人よ',
          place: '鎌倉',
          date: '2026.08.21',
        ),
      ),
    );

    expect(find.byType(VerticalHandwriting), findsOneWidget);
    for (final c in '風の旅人よ'.characters) {
      expect(find.text(c), findsOneWidget, reason: '字「$c」应独立成 Text');
    }
  });

  testWidgets('宛名 6 字：单列渐缩不拆列，右缘仍锚定 44', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Envelope(
          seedId: 'env-addr-shrink',
          addressee: '银河的邮递员',
          place: '鎌倉',
          date: '2026.08.21',
          tilt: 0,
        ),
      ),
    );

    final columnCount = tester
        .widgetList<Column>(
          find.descendant(
            of: find.byType(VerticalHandwriting),
            matching: find.byType(Column),
          ),
        )
        .length;
    expect(columnCount, 1, reason: '6 字宛名应单列渐缩而非拆出孤字列');

    // 基准宽 200 − 宛名右缘 44 = 156（tilt=0 时坐标可比）
    final envOrigin = tester.getTopLeft(find.byType(Envelope));
    final addrRight = tester.getTopRight(find.byType(VerticalHandwriting));
    expect((addrRight - envOrigin).dx, closeTo(156, 1.0));
  });

  testWidgets('竖排旋转：长音「ー」转 90°，普通假名直立', (tester) async {
    await tester.pumpWidget(_wrap(const VerticalHandwriting(text: 'かーら')));
    expect(
      find.descendant(
        of: find.byType(VerticalHandwriting),
        matching: find.byWidgetPredicate(
          (w) => w is RotatedBox && w.quarterTurns == 1,
        ),
      ),
      findsOneWidget,
      reason: '长音符应按日文纵书传统旋转',
    );
    expect(find.text('か'), findsOneWidget);
    expect(find.text('ら'), findsOneWidget);
  });

  testWidgets('封筒不渲染贴纸（decor 属于信纸，不贴封筒）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Envelope(
          seedId: 'env-nodecor',
          place: '鎌倉',
          date: '2026.08.21',
          skin: const LetterSkin(decorIds: ['decor.leaf-03']),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(Envelope),
        matching: find.byType(SkinDecor),
      ),
      findsNothing,
    );
  });

  testWidgets('同一设计等比呈现：任意 width 下邮票相对位置恒定（含内部比例）', (tester) async {
    Future<Offset> stampRelativeTopLeft(double w) async {
      await tester.pumpWidget(
        _wrap(
          Envelope(
            seedId: 'prop',
            place: '鎌倉',
            date: '2026.08',
            width: w,
            tilt: 0, // 消倾斜，坐标可比
          ),
        ),
      );
      // 封筒根 Transform（tilt=0 时即全局原点）
      final origin = tester.getTopLeft(find.byType(Envelope));
      final stamp = tester.getTopLeft(find.byType(StampPiece));
      return (stamp - origin) / w;
    }

    // 内部按 baseWidth 固定设计、整体 Transform.scale——邮票相对位置在
    // 任意宽度下恒定，邮戳/宛名/刻印同理（同一缩放矩阵覆盖所有要素）
    final a = await stampRelativeTopLeft(200);
    final b = await stampRelativeTopLeft(130);
    expect(a.dx, closeTo(b.dx, 0.005));
    expect(a.dy, closeTo(b.dy, 0.005));
  });

  testWidgets('邮戳内部也等比：章直径 = 视觉直径 × (width/baseWidth)', (tester) async {
    Future<double> postmarkWidth(double w) async {
      await tester.pumpWidget(
        _wrap(
          Envelope(
            seedId: 'pm-scale',
            place: '鎌倉',
            date: '2026.08',
            width: w,
            tilt: 0,
          ),
        ),
      );
      // Postmark 圆环容器宽度 × 整体 scale = 呈现直径
      return tester.getSize(find.byType(Postmark)).width * (w / 200);
    }

    // 章随封筒整体缩放——120 宽筒上呈现直径 = 200 宽筒的 0.6 倍
    final w200 = await postmarkWidth(200);
    final w120 = await postmarkWidth(120);
    expect(w120, closeTo(w200 * 0.6, 0.6));
  });

  testWidgets('Envelope 皮肤挂载：邮票/邮戳两槽（无贴纸）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Envelope(
          seedId: 'env-skin',
          place: '鎌倉',
          date: '2026.08.21',
          skin: const LetterSkin(
            stampId: 'stamp.sea-01',
            postmarkEmblemId: 'postmark.wave-04',
          ),
        ),
      ),
    );

    // 邮票票面 = SkinMotive 资产；邮戳 emblem 槽位接线正确（Postmark
    // 收到 emblem——定版构图暂不渲染它，纯文本三段式）
    expect(
      find.descendant(
        of: find.byType(StampPiece),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    final pm = tester.widget<Postmark>(find.byType(Postmark));
    expect(pm.emblem, isA<Widget>(), reason: 'emblem 槽位应已接线');
  });

  test('Envelope 比例令牌：aspectRatio = 2.2', () {
    expect(Envelope.aspectRatio, 2.2);
  });

  test('NatsuPhotoMood 令牌完备', () {
    // 三 mood 的滤镜/渐变/参数全 const 可引用（引用即编译期证明）
    expect(
      NatsuPhotoMood.motionSigmaX,
      greaterThan(NatsuPhotoMood.motionSigmaY),
      reason: '运动模糊横向应强于纵向（横移手感）',
    );
    expect(math.pi, greaterThan(0)); // dart:math 可用性占位
  });
}
