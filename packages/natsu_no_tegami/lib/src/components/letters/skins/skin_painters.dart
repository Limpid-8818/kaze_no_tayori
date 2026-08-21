import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 夏の手紙 v2 · 皮肤资产 painter — 纯几何简笔，零依赖
///
/// 风格基准 = StampPiece 默认票面（`_SunAndWavePainter`）：stroke 1.5、
/// round cap、单色 90% alpha、克制。颜色一律由构造传入（注册表里绑
/// NatsuColors 常量，用色纪律落在一处）；全部 const 实例、无状态
/// （`shouldRepaint` 恒 false）。
///
/// 意象语源：蝉/海/雨/電車/夕焼/花火/夜風——只是图案出处，不是成套概念。

Paint _ink(Color color, {double width = 1.5}) => Paint()
  ..color = color.withValues(alpha: 0.9)
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round;

// ---- 邮票槽（票面构图）-------------------------------------------------------

/// 海 — 小圆日 + 三行短弧浪（浪是主角，占下 2/3）
class SeaStampPainter extends CustomPainter {
  const SeaStampPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color);

    // 残日：小圆，不抢浪的戏
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.22),
      size.width * 0.13,
      paint,
    );

    // 三行短弧浪（行距渐宽，近大远小）
    for (var row = 0; row < 3; row++) {
      final y = size.height * (0.46 + row * 0.16);
      final amp = 3.0 + row * 1.2;
      final path = Path()..moveTo(size.width * 0.08, y);
      for (var x = size.width * 0.08;
          x < size.width * 0.92 - 8;
          x += 8) {
        path.quadraticBezierTo(x + 4, y - amp, x + 8, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SeaStampPainter oldDelegate) => false;
}

/// 雨 — 五条斜平行短线 + 底部一枚水洼
class RainStampPainter extends CustomPainter {
  const RainStampPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color);

    // 斜雨：-30° 短线，五行错位（落下来的节奏，不是网格）
    const dy = -0.5; // tan(30°) 的近似斜率
    for (var i = 0; i < 5; i++) {
      final cx = size.width * (0.22 + 0.14 * i);
      final cy = size.height * (0.20 + 0.075 * (i % 2));
      final len = size.height * 0.16;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + len * dy, cy + len),
        paint,
      );
    }

    // 水洼：扁椭圆，雨停后留下的
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.82),
        width: size.width * 0.52,
        height: size.width * 0.16,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant RainStampPainter oldDelegate) => false;
}

/// 夕焼 — 地平线上的半圆日 + 上半放射线 + 两条海面余光
class DuskStampPainter extends CustomPainter {
  const DuskStampPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color);
    final horizon = size.height * 0.62;
    final r = size.width * 0.20;
    final center = Offset(size.width * 0.5, horizon);

    // 地平线
    canvas.drawLine(
      Offset(size.width * 0.06, horizon),
      Offset(size.width * 0.94, horizon),
      paint,
    );

    // 半圆日：坐在地平线上
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), math.pi, math.pi, false, paint);

    // 放射线：只画上半（光往上走）
    for (final a in [math.pi * 1.15, math.pi * 1.35, math.pi * 1.65, math.pi * 1.85]) {
      canvas.drawLine(
        center + Offset(math.cos(a) * (r + 3), math.sin(a) * (r + 3)),
        center + Offset(math.cos(a) * (r + 8), math.sin(a) * (r + 8)),
        paint,
      );
    }

    // 海面余光：两条渐短的横线
    canvas.drawLine(
      Offset(size.width * 0.28, horizon + size.height * 0.13),
      Offset(size.width * 0.72, horizon + size.height * 0.13),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, horizon + size.height * 0.24),
      Offset(size.width * 0.62, horizon + size.height * 0.24),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant DuskStampPainter oldDelegate) => false;
}

/// 夜風 — 上弦月 + 三条 S 形风线 + 一颗小星
class NightWindStampPainter extends CustomPainter {
  const NightWindStampPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color);

    // 上弦月：两圆相减（Path.combine difference）
    final moonR = size.width * 0.17;
    final moonC = Offset(size.width * 0.58, size.height * 0.26);
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moonC, radius: moonR)),
      Path()
        ..addOval(Rect.fromCircle(
          center: moonC + Offset(moonR * 0.5, -moonR * 0.35),
          radius: moonR * 0.85,
        )),
    );
    canvas.drawPath(moon, paint);

    // 小星：十字
    final star = Offset(size.width * 0.24, size.height * 0.18);
    canvas.drawLine(star - const Offset(3, 0), star + const Offset(3, 0), paint);
    canvas.drawLine(star - const Offset(0, 3), star + const Offset(0, 3), paint);

    // 风线：三条 S 形贝塞尔，掠过纸面
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.55 + i * 0.14);
      final path = Path()
        ..moveTo(size.width * 0.10, y)
        ..cubicTo(
          size.width * 0.32, y - 8 - i * 2,
          size.width * 0.48, y + 6,
          size.width * 0.66, y - 2,
        )
        ..quadraticBezierTo(size.width * 0.80, y - 6, size.width * 0.90, y - 1);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant NightWindStampPainter oldDelegate) => false;
}

// ---- 邮戳槽（中心图案，40×40 语义，全珊瑚——盖章油墨统一）-------------------

/// 蝉 — 菱身 + 双侧翅 + 头部小圆
class CicadaEmblemPainter extends CustomPainter {
  const CicadaEmblemPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color, width: 1.6);
    final w = size.width;
    final h = size.height;

    // 头
    canvas.drawCircle(Offset(w * 0.5, h * 0.22), w * 0.07, paint);

    // 菱形身（头部下方到腹部尖）
    final body = Path()
      ..moveTo(w * 0.5, h * 0.32)
      ..lineTo(w * 0.61, h * 0.54)
      ..lineTo(w * 0.5, h * 0.84)
      ..lineTo(w * 0.39, h * 0.54)
      ..close();
    canvas.drawPath(body, paint);

    // 双翅：两侧斜椭圆（旋转绘制）
    for (final side in [1.0, -1.0]) {
      canvas.save();
      canvas.translate(w * 0.5 + side * w * 0.20, h * 0.44);
      canvas.rotate(side * 24 * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: w * 0.34,
          height: w * 0.15,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CicadaEmblemPainter oldDelegate) => false;
}

/// 電車 — 圆角车身 + 三窗 + 双轮 + 受电杆
class TramEmblemPainter extends CustomPainter {
  const TramEmblemPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color, width: 1.6);
    final w = size.width;
    final h = size.height;

    // 车身
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.34, w * 0.76, h * 0.34),
        Radius.circular(w * 0.06),
      ),
      paint,
    );

    // 三扇窗
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          w * (0.20 + i * 0.22),
          h * 0.41,
          w * 0.13,
          h * 0.14,
        ),
        paint,
      );
    }

    // 双轮
    canvas.drawCircle(Offset(w * 0.28, h * 0.74), w * 0.06, paint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.74), w * 0.06, paint);

    // 受电杆：斜线向上 + 顶部小横杆
    canvas.drawLine(
      Offset(w * 0.52, h * 0.34),
      Offset(w * 0.68, h * 0.14),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.60, h * 0.14),
      Offset(w * 0.76, h * 0.14),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant TramEmblemPainter oldDelegate) => false;
}

/// 花火 — 中心点 + 八条放射线带籽 + 散点星
class FireworksEmblemPainter extends CustomPainter {
  const FireworksEmblemPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color, width: 1.6);
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.55);
    final r1 = w * 0.10;
    final r2 = w * 0.32;

    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      final outer = center + Offset(math.cos(a) * r2, math.sin(a) * r2);
      canvas.drawLine(
        center + Offset(math.cos(a) * r1, math.sin(a) * r1),
        outer,
        paint,
      );
      // 籽火：放射线外端的小圆点（断线感）
      canvas.drawCircle(outer, 1.6, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }

    // 散点星：两颗，避开对称
    canvas.drawCircle(Offset(w * 0.18, h * 0.20), 1.4, paint);
    canvas.drawCircle(Offset(w * 0.84, h * 0.30), 1.2, paint);
  }

  @override
  bool shouldRepaint(covariant FireworksEmblemPainter oldDelegate) => false;
}

/// 波 — 卷浪弧 + 三颗泡沫
class WaveEmblemPainter extends CustomPainter {
  const WaveEmblemPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color, width: 1.6);
    final w = size.width;
    final h = size.height;

    // 卷浪：一道大弧从左下涌起，向右卷出头
    final wave = Path()
      ..moveTo(w * 0.08, h * 0.78)
      ..cubicTo(
        w * 0.10, h * 0.40,
        w * 0.34, h * 0.22,
        w * 0.58, h * 0.30,
      )
      ..quadraticBezierTo(w * 0.74, h * 0.36, w * 0.72, h * 0.50);
    canvas.drawPath(wave, paint);

    // 浪内回勾：让卷有厚度
    final inner = Path()
      ..moveTo(w * 0.24, h * 0.62)
      ..quadraticBezierTo(w * 0.34, h * 0.42, w * 0.54, h * 0.44);
    canvas.drawPath(inner, paint);

    // 泡沫：三颗小圆沿浪脊
    canvas.drawCircle(Offset(w * 0.66, h * 0.34), w * 0.035, paint);
    canvas.drawCircle(Offset(w * 0.76, h * 0.46), w * 0.028, paint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.52), w * 0.024, paint);
  }

  @override
  bool shouldRepaint(covariant WaveEmblemPainter oldDelegate) => false;
}

// ---- 装饰槽（贴纸语义，禁珊瑚——配给制不开口子）-----------------------------

/// 貝殻 — 扇形 + 三条放射棱线
class ShellDecorPainter extends CustomPainter {
  const ShellDecorPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color);
    final w = size.width;
    final h = size.height;
    final apex = Offset(w * 0.5, h * 0.88);

    // 扇形：顶点 + 两侧直线 + 上缘弧
    final fan = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(w * 0.16, h * 0.42)
      ..quadraticBezierTo(w * 0.5, h * 0.14, w * 0.84, h * 0.42)
      ..close();
    canvas.drawPath(fan, paint);

    // 棱线：顶点到上缘的三条放射线
    for (final t in [0.28, 0.5, 0.72]) {
      final dx = w * (0.16 + t * 0.68);
      final dy = h * 0.42 - math.sin(t * math.pi) * h * 0.18;
      canvas.drawLine(apex, Offset(dx, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ShellDecorPainter oldDelegate) => false;
}

/// 線香花火 — 垂直梗 + 顶端放射 + 籽火圆点
///
/// sunlightYellow 在白纸上作细线可见度边缘——描边加重到 2.0、籽火用
/// 实心点补视觉重量（阳光黄只禁作文字色，不作线条）。
class SparklerDecorPainter extends CustomPainter {
  const SparklerDecorPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color, width: 2.0);
    final w = size.width;
    final h = size.height;
    final burst = Offset(w * 0.5, h * 0.34);

    // 梗
    canvas.drawLine(
      Offset(w * 0.5, h * 0.92),
      Offset(w * 0.5, h * 0.44),
      paint,
    );

    // 顶端放射：六条短线
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + math.pi / 6;
      final inner = burst + Offset(math.cos(a) * w * 0.07, math.sin(a) * w * 0.07);
      final outer = burst + Offset(math.cos(a) * w * 0.22, math.sin(a) * w * 0.22);
      canvas.drawLine(inner, outer, paint);
      // 籽火：实心小点（线香花火的火粒）
      canvas.drawCircle(outer, 1.8, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }

    // 燃点
    canvas.drawCircle(burst, w * 0.035, paint);
  }

  @override
  bool shouldRepaint(covariant SparklerDecorPainter oldDelegate) => false;
}

/// 葉 — 双贝塞尔叶形 + 中脉
class LeafDecorPainter extends CustomPainter {
  const LeafDecorPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _ink(color);
    final w = size.width;
    final h = size.height;
    final tip = Offset(w * 0.5, h * 0.10);
    final base = Offset(w * 0.5, h * 0.90);

    // 叶形：两条外弓贝塞尔（左右不对称一点点——叶子本来就不对称）
    final leaf = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(w * 0.04, h * 0.42, base.dx, base.dy)
      ..quadraticBezierTo(w * 0.96, h * 0.58, tip.dx, tip.dy)
      ..close();
    canvas.drawPath(leaf, paint);

    // 中脉：微曲一线
    final midrib = Path()
      ..moveTo(tip.dx, tip.dy + 2)
      ..quadraticBezierTo(w * 0.54, h * 0.5, base.dx, base.dy - 2);
    canvas.drawPath(midrib, paint);
  }

  @override
  bool shouldRepaint(covariant LeafDecorPainter oldDelegate) => false;
}
