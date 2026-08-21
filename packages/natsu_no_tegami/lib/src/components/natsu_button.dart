import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 按钮
///
/// 语义纪律：
/// - [NatsuButtonVariant.primary]（墨蓝底白字）— 每屏至多一个（写信/投递等主行动）
/// - [NatsuButtonVariant.secondary]（白纸+发丝线）— 常规行动
/// - [NatsuButtonVariant.ghost]（无底无线）— 低强调（「让它继续旅行」）
/// - [NatsuButtonVariant.destructive]（珊瑚红）— 仅举报/删除类
///
/// 交互：按压 = 墨蓝 8% 覆盖（纸被指尖按下），聚焦 = 夏空蓝 1.5px 环，
/// 无阴影（UI 骨架贴结构层），纸感缓动 120ms。
class NatsuButton extends StatefulWidget {
  const NatsuButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = NatsuButtonVariant.secondary,
    this.size = NatsuButtonSize.md,
    this.autofocus = false,
  });

  /// 主行动；null 时按钮禁用（内容 32% 透明，不发灰底）。
  final VoidCallback? onPressed;

  /// 按钮文字（中文/日文皆可，走ゴシック+SC 回退链）。
  final Widget child;

  final NatsuButtonVariant variant;
  final NatsuButtonSize size;
  final bool autofocus;

  @override
  State<NatsuButton> createState() => _NatsuButtonState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty('variant', variant));
    properties.add(EnumProperty('size', size));
  }
}

enum NatsuButtonVariant { primary, secondary, ghost, destructive }

enum NatsuButtonSize { sm, md }

class _NatsuButtonState extends State<NatsuButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final v = widget.variant;

    // 禁用态：所有变体统一降为纸色调——深底变体（primary/destructive）
    // 禁用时保留深底会得到「深底浅字」的坏对比，降饱和纸底 + 32% 墨蓝
    // 文字才是明确的「不可按」。
    final bgColor = !enabled
        ? NatsuColors.envelope
        : switch (v) {
            NatsuButtonVariant.primary => NatsuColors.inkBlue,
            NatsuButtonVariant.secondary => NatsuColors.paperWhite,
            NatsuButtonVariant.ghost => Colors.transparent,
            NatsuButtonVariant.destructive => NatsuColors.error,
          };

    final fgColor = switch (v) {
      NatsuButtonVariant.primary => NatsuColors.onInk,
      NatsuButtonVariant.secondary => NatsuColors.inkBlue,
      NatsuButtonVariant.ghost => NatsuColors.inkBlue,
      NatsuButtonVariant.destructive => NatsuColors.onCoral,
    };

    final borderColor = !enabled
        ? NatsuColors.paperEdge
        : switch (v) {
            NatsuButtonVariant.primary => NatsuColors.inkBlue,
            NatsuButtonVariant.secondary => Color(0xFFD5D0C4),
            NatsuButtonVariant.ghost => Colors.transparent,
            NatsuButtonVariant.destructive => NatsuColors.error,
          };

    // 交互覆盖层：hover 4% / pressed 8%（墨色，纸的暗化）
    final Color overlay;
    if (!enabled) {
      overlay = Colors.transparent;
    } else if (_pressed) {
      overlay = NatsuColors.pressedOverlay;
    } else if (_hovered) {
      overlay = NatsuColors.hoverOverlay;
    } else {
      overlay = Colors.transparent;
    }

    final py = widget.size == NatsuButtonSize.md
        ? NatsuSpacing.btnPaddingY
        : NatsuSpacing.btnSmPaddingY;
    final px = widget.size == NatsuButtonSize.md
        ? NatsuSpacing.btnPaddingX
        : NatsuSpacing.btnSmPaddingX;

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: enabled
          ? (h) => setState(() => _hovered = h)
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: NatsuMotion.short,
          curve: NatsuMotion.easing,
          padding: EdgeInsets.symmetric(vertical: py, horizontal: px),
          decoration: BoxDecoration(
            color: Color.alphaBlend(overlay, bgColor),
            borderRadius: BorderRadius.circular(NatsuRadius.card),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: DefaultTextStyle(
            style: NatsuTypography.button.copyWith(
              color: enabled ? fgColor : NatsuColors.disabledContent,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                size: 18,
                color: enabled ? fgColor : NatsuColors.disabledContent,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
