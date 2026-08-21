import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 滑块 — 纯 widgets 手势实现
///
/// 4px 纸缘轨道 + 夏空蓝活跃段 + 16px 白旋钮（输入线描边）。
/// 选中语言同族：活跃段 = 被光照到。手势区 44px（轨道垂直居中），
/// 支持 tap 跳转与水平拖动。UI 骨架 — 0°、无阴影。
class NatsuSlider extends StatefulWidget {
  const NatsuSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.enabled = true,
  });

  /// 当前值（自动 clamp 到 [min, max]）
  final double value;

  /// 拖动/点按回调；null 时禁用
  final ValueChanged<double>? onChanged;

  final double min;
  final double max;

  final bool enabled;

  @override
  State<NatsuSlider> createState() => _NatsuSliderState();
}

class _NatsuSliderState extends State<NatsuSlider> {
  bool _hovered = false;
  bool _dragging = false;

  final GlobalKey _trackKey = GlobalKey();

  double get _fraction {
    final span = widget.max - widget.min;
    if (span <= 0) return 0;
    return ((widget.value - widget.min) / span).clamp(0.0, 1.0);
  }

  void _updateFromPosition(double dx) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || box.size.width <= 0) return;
    final f = (dx / box.size.width).clamp(0.0, 1.0);
    final v = widget.min + (widget.max - widget.min) * f;
    widget.onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onChanged != null;
    final f = _fraction;

    return FocusableActionDetector(
      mouseCursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: active ? (h) => setState(() => _hovered = h) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active
            ? (d) => _updateFromPosition(d.localPosition.dx)
            : null,
        onHorizontalDragStart: active
            ? (d) => setState(() => _dragging = true)
            : null,
        onHorizontalDragUpdate: active
            ? (d) => _updateFromPosition(d.localPosition.dx)
            : null,
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        child: SizedBox(
          height: NatsuSpacing.controlHitTarget,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 旋钮不越轨：轨道两侧各缩进半个旋钮
              final inset = NatsuSpacing.sliderKnob / 2;
              final trackW = constraints.maxWidth - NatsuSpacing.sliderKnob;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Center(
                  child: SizedBox(
                    key: _trackKey,
                    height: NatsuSpacing.controlHitTarget,
                    width: trackW > 0 ? trackW : 0,
                    child: _Track(
                      fraction: f,
                      hovered: _hovered || _dragging,
                      active: active,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 轨道 + 活跃段 + 旋钮 — fraction ∈ [0,1]
class _Track extends StatelessWidget {
  const _Track({
    required this.fraction,
    required this.hovered,
    required this.active,
  });

  final double fraction;
  final bool hovered;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment(fraction * 2 - 1, 0);

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // 底轨：4px 纸缘药丸
        Container(
          height: NatsuSpacing.sliderTrackH,
          decoration: BoxDecoration(
            color: active ? NatsuColors.paperEdge : NatsuColors.envelope,
            borderRadius: BorderRadius.circular(NatsuSpacing.sliderTrackH / 2),
          ),
        ),
        // 活跃段：从左生长到旋钮位置（夏空蓝，被光照到）
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
              height: NatsuSpacing.sliderTrackH,
              decoration: BoxDecoration(
                color: active ? NatsuColors.skyBlue : NatsuColors.paperEdge,
                borderRadius: BorderRadius.circular(
                  NatsuSpacing.sliderTrackH / 2,
                ),
              ),
            ),
          ),
        ),
        // 旋钮：16px 白圆（hover/拖动时描边转夏空蓝）
        Align(
          alignment: alignment,
          child: AnimatedContainer(
            duration: NatsuMotion.short,
            curve: NatsuMotion.easing,
            width: NatsuSpacing.sliderKnob,
            height: NatsuSpacing.sliderKnob,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NatsuColors.paperWhite,
              border: Border.all(
                color: !active
                    ? NatsuColors.paperEdge
                    : hovered
                    ? NatsuColors.skyBlue
                    : NatsuBorders.inputSide.color,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
