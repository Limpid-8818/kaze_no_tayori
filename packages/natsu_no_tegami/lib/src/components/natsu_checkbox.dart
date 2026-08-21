import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 复选框
///
/// 18px 方块（radius card）：未选 = 白底输入线；选中 = 夏空蓝底 + 白勾。
/// 勾为 CustomPainter 描线，选中瞬间 0→1 扫出——「墨被写上」的一瞬。
/// tristate 时 null = 半选（横线）。UI 骨架 — 0°、无阴影。
class NatsuCheckbox extends StatefulWidget {
  const NatsuCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.tristate = false,
  });

  /// 当前态；tristate 下 null = 半选
  final bool? value;

  /// 切换回调；null 时禁用
  final ValueChanged<bool?>? onChanged;

  final bool enabled;

  /// 三态模式（半选用于「全选子集」场景）
  final bool tristate;

  @override
  State<NatsuCheckbox> createState() => _NatsuCheckboxState();
}

class _NatsuCheckboxState extends State<NatsuCheckbox> {
  bool _hovered = false;
  bool _pressed = false;

  bool? get _next {
    if (!widget.tristate) return !(widget.value ?? false);
    // tristate 循环：false → true → null → false
    if (widget.value == null) return false;
    if (widget.value == true) return null;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onChanged != null;
    final checked = widget.value == true;
    final tristateMixed = widget.tristate && widget.value == null;

    final Color fill = !active
        ? NatsuColors.envelope
        : checked
            ? NatsuColors.skyBlue
            : NatsuColors.paperWhite;

    final Color overlay;
    if (!active) {
      overlay = Colors.transparent;
    } else if (_pressed) {
      overlay = NatsuColors.pressedOverlay;
    } else if (_hovered) {
      overlay = NatsuColors.hoverOverlay;
    } else {
      overlay = Colors.transparent;
    }

    return FocusableActionDetector(
      mouseCursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: active ? (h) => setState(() => _hovered = h) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: active ? () => setState(() => _pressed = false) : null,
        onTapUp: active ? (_) => setState(() => _pressed = false) : null,
        onTap: active ? () => widget.onChanged!(_next) : null,
        child: SizedBox(
          width: NatsuSpacing.controlHitTarget,
          height: NatsuSpacing.controlHitTarget,
          child: Center(
            child: TweenAnimationBuilder<double>(
              // 半选（tristate null）保持满格；勾的描线只在 true 时扫出
              tween: Tween<double>(
                  begin: 0, end: checked || tristateMixed ? 1 : 0),
              duration: NatsuMotion.short,
              curve: NatsuMotion.easing,
              builder: (context, t, _) => Container(
                width: NatsuSpacing.checkSize,
                height: NatsuSpacing.checkSize,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(overlay, fill),
                  borderRadius: BorderRadius.circular(NatsuRadius.card),
                  border: Border.fromBorderSide(
                    checked || tristateMixed
                        ? BorderSide(
                            color: active
                                ? NatsuColors.skyBlue
                                : NatsuColors.paperEdge,
                            width: 1)
                        : active
                            ? NatsuBorders.inputSide
                            : BorderSide(
                                color: NatsuColors.paperEdge, width: 1),
                  ),
                ),
                child: CustomPaint(
                  painter: _CheckMarkPainter(
                    progress: t,
                    mixed: tristateMixed,
                    color: NatsuColors.onInk,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 勾/横线描线画笔 — progress 驱动 PathMetrics 截取（墨被写上）
class _CheckMarkPainter extends CustomPainter {
  _CheckMarkPainter({
    required this.progress,
    required this.mixed,
    required this.color,
  });

  final double progress;
  final bool mixed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (mixed) {
      // 半选：短横线（居中，宽 8，随 progress 从中心扫出）
      final midY = size.height / 2;
      final half = 4 * progress;
      canvas.drawLine(Offset(size.width / 2 - half, midY),
          Offset(size.width / 2 + half, midY), paint);
      return;
    }

    // 全选勾路径（18px 盒内坐标）
    final path = Path()
      ..moveTo(4, 9.5)
      ..lineTo(7.8, 13)
      ..lineTo(14, 5);
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_CheckMarkPainter old) =>
      old.progress != progress || old.mixed != mixed;
}
