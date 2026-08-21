import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 加载指示 — 邮戳环
///
/// CustomPainter 270° 墨蓝弧线（留 90° 缺口 = 邮戳的断墨）持续旋转。
/// 连续旋转用 linear 曲线——纸感缓动只属于状态过渡，不属于匀速转动。
/// UI 骨架 — 0°、无阴影。RepaintBoundary 隔离重绘。
class NatsuSpinner extends StatefulWidget {
  const NatsuSpinner({super.key, this.size = NatsuSpinnerSize.md});

  final NatsuSpinnerSize size;

  @override
  State<NatsuSpinner> createState() => _NatsuSpinnerState();
}

enum NatsuSpinnerSize { sm, md }

class _NatsuSpinnerState extends State<NatsuSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NatsuMotion.long,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size == NatsuSpinnerSize.md
        ? NatsuSpacing.spinnerMd
        : NatsuSpacing.spinnerSm;
    return RepaintBoundary(
      child: SizedBox(
        width: d,
        height: d,
        child: RotationTransition(
          turns: _controller,
          child: CustomPaint(
            painter: _StampRingPainter(color: NatsuColors.inkBlue),
          ),
        ),
      ),
    );
  }
}

/// 邮戳环画笔 — 270° 弧（断墨缺口在右上，随整体旋转）
class _StampRingPainter extends CustomPainter {
  _StampRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius - 1,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // 从 -45° 起画 270°：缺口朝右上（邮戳的断墨感）
    canvas.drawArc(rect, -math.pi / 4, 3 * math.pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(_StampRingPainter old) => old.color != color;
}
