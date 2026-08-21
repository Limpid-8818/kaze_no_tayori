import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 开关
///
/// 轨道药丸：关 = 纸缘灰、开 = 夏空蓝（被光照到，与 Tag/Checkbox 选中语言
/// 一致）；白旋钮 14px 滑动。UI 骨架 — 严格 0°、无阴影、无 Imperfection。
/// 命中区 44px（触控标准），轨道视觉居中。
class NatsuSwitch extends StatefulWidget {
  const NatsuSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// 当前态
  final bool value;

  /// 切换回调；null 时禁用（轨道降为纸色调）
  final ValueChanged<bool>? onChanged;

  /// 置 false 同样禁用（显式语义，与 onChanged: null 等效）
  final bool enabled;

  @override
  State<NatsuSwitch> createState() => _NatsuSwitchState();
}

class _NatsuSwitchState extends State<NatsuSwitch> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onChanged != null;

    // 禁用统一降纸色调（与按钮禁用策略一致）
    final Color track = !active
        ? NatsuColors.envelope
        : widget.value
        ? NatsuColors.skyBlue
        : NatsuColors.paperEdge;

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
        onTap: active ? () => widget.onChanged!(!widget.value) : null,
        child: SizedBox(
          width: NatsuSpacing.controlHitTarget,
          height: NatsuSpacing.controlHitTarget,
          child: Center(
            child: AnimatedContainer(
              duration: NatsuMotion.short,
              curve: NatsuMotion.easing,
              width: NatsuSpacing.switchTrackW,
              height: NatsuSpacing.switchTrackH,
              decoration: BoxDecoration(
                color: Color.alphaBlend(overlay, track),
                borderRadius: BorderRadius.circular(
                  NatsuSpacing.switchTrackH / 2,
                ),
              ),
              child: AnimatedAlign(
                duration: NatsuMotion.short,
                curve: NatsuMotion.easing,
                // 旋钮左右各留 3px 内缩（(20-14)/2）
                alignment: widget.value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: _SwitchKnob(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 白旋钮 — 1px 纸缘描边保证在白色演示底上的轮廓
class _SwitchKnob extends StatelessWidget {
  const _SwitchKnob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NatsuSpacing.switchKnob,
      height: NatsuSpacing.switchKnob,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: NatsuColors.paperWhite,
        border: Border.fromBorderSide(NatsuBorders.side),
      ),
    );
  }
}
