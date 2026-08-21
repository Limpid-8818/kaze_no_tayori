import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 单选
///
/// 20px 圆环：未选 = 白底输入线；选中 = 夏空蓝 1.5px 环 + 10px 内点
/// （scale-in，「被光点亮」）。泛型分组值。UI 骨架 — 0°、无阴影。
class NatsuRadio<T> extends StatefulWidget {
  const NatsuRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.enabled = true,
  });

  /// 本项的值
  final T value;

  /// 当前组选中值（null = 无选中）
  final T? groupValue;

  /// 选择回调；null 时禁用
  final ValueChanged<T>? onChanged;

  final bool enabled;

  @override
  State<NatsuRadio<T>> createState() => _NatsuRadioState<T>();
}

class _NatsuRadioState<T> extends State<NatsuRadio<T>> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onChanged != null;
    final selected = widget.value == widget.groupValue;

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
        onTap: active && !selected ? () => widget.onChanged!(widget.value) : null,
        child: SizedBox(
          width: NatsuSpacing.controlHitTarget,
          height: NatsuSpacing.controlHitTarget,
          child: Center(
            child: AnimatedContainer(
              duration: NatsuMotion.short,
              curve: NatsuMotion.easing,
              width: NatsuSpacing.radioSize,
              height: NatsuSpacing.radioSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.alphaBlend(overlay, NatsuColors.paperWhite),
                border: Border.all(
                  color: !active
                      ? NatsuColors.paperEdge
                      : selected
                          ? NatsuColors.skyBlue
                          : NatsuBorders.inputSide.color,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: AnimatedScale(
                  duration: NatsuMotion.short,
                  curve: NatsuMotion.easing,
                  scale: selected ? 1 : 0,
                  child: const SizedBox(
                    width: 10,
                    height: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NatsuColors.skyBlue,
                      ),
                    ),
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
