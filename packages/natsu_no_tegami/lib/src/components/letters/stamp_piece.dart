import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tokens/natsu_tokens.dart';
import 'scaled_design.dart';

/// 夏の手紙 v2 · 邮票 — 旅行标记
///
/// 固定 viewBox 设计（基准 64×80）+ 整体等比缩放：锯齿步距、白边、
/// 面值字号全部活在基准坐标系里——[width] 只决定呈现大小，视觉表现
/// 任何尺寸下同构（像 SVG 开箱即用）。
///
/// 真锯齿边：`_PerforationClipper` 用 Path.combine(difference) 从矩形
/// 沿四边每 6px 减去半径 2.5 的半圆。票面 [motive] 可自定（默认 leaf 色
/// 简笔太阳与波浪），角上珊瑚色「夏」面值。种子倾斜——邮票从不贴正。
class StampPiece extends StatelessWidget {
  const StampPiece({
    super.key,
    required this.seedId,
    this.motive,
    this.width = 64,
  });

  /// 种子 ID（倾斜来源）
  final String seedId;

  /// 票面内容；null = 默认简笔太阳/波浪
  final Widget? motive;

  /// 呈现宽；高 = width / [aspectRatio]（比例锁定 0.8）
  final double width;

  /// 票面宽高比（宽/高）——真实邮票的竖式比例，不可变
  static const double aspectRatio = 0.8;

  /// 基准设计尺寸（viewBox）——内部一切 px 以它为参照
  static const double baseWidth = 64;

  static const double baseHeight = baseWidth / aspectRatio;

  @override
  Widget build(BuildContext context) {
    final angle = NatsuImperfection.tiltOf(seedId) * math.pi / 180;

    return Transform.rotate(
      angle: angle,
      child: ScaledDesign(
        baseWidth: baseWidth,
        baseHeight: baseHeight,
        width: width,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: NatsuShadows.paperResting,
          ),
          child: ClipPath(
            clipper: _PerforationClipper(),
            child: Container(
              color: NatsuColors.paperWhite,
              padding: const EdgeInsets.all(7),
              child: Stack(
                children: [
                  Positioned.fill(child: motive ?? const _DefaultMotive()),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Text(
                      '夏',
                      style: NatsuTypography.hwSeal.copyWith(
                        fontSize: 14,
                        height: 1.2,
                        color: NatsuColors.coralStamp.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 锯齿边 — 矩形减去四边等距半圆（基准坐标系里的固定步距）
class _PerforationClipper extends CustomClipper<Path> {
  static const double step = 6.0;
  static const double r = 2.5;

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    var path = Path()..addRect(rect);

    final cut = Path();
    // 上边与下边
    for (var x = step / 2; x < size.width; x += step) {
      cut.addOval(Rect.fromCircle(center: Offset(x, 0), radius: r));
      cut.addOval(
          Rect.fromCircle(center: Offset(x, size.height), radius: r));
    }
    // 左边与右边
    for (var y = step / 2; y < size.height; y += step) {
      cut.addOval(Rect.fromCircle(center: Offset(0, y), radius: r));
      cut.addOval(Rect.fromCircle(center: Offset(size.width, y), radius: r));
    }

    return Path.combine(PathOperation.difference, path, cut);
  }

  @override
  bool shouldReclip(_PerforationClipper oldClipper) => false;
}

/// 默认票面 — leaf 色简笔太阳与波浪
class _DefaultMotive extends StatelessWidget {
  const _DefaultMotive();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SunAndWavePainter(),
      size: Size.infinite,
    );
  }
}

class _SunAndWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NatsuColors.leaf.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // 太阳：圆 + 放射短线
    final center = Offset(size.width / 2, size.height * 0.34);
    final r = size.width * 0.16;
    canvas.drawCircle(center, r, paint..style = PaintingStyle.stroke);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final inner = Offset(
        center.dx + math.cos(a) * (r + 3),
        center.dy + math.sin(a) * (r + 3),
      );
      final outer = Offset(
        center.dx + math.cos(a) * (r + 7),
        center.dy + math.sin(a) * (r + 7),
      );
      canvas.drawLine(inner, outer, paint);
    }

    // 波浪：三行短弧
    for (var row = 0; row < 3; row++) {
      final y = size.height * (0.58 + row * 0.12);
      final phase = row * 0.8;
      final path = Path()..moveTo(6, y);
      for (var x = 6.0; x < size.width - 6; x += 8) {
        path.quadraticBezierTo(
          x + 4 + phase,
          y - 3 - row,
          x + 8,
          y,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
