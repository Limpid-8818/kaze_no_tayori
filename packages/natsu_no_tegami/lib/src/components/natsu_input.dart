import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 输入框
///
/// 48px 高、稍深输入线、聚焦夏空线、错误朱线（克制——错误是少数
/// 需要拉响的场景，但仅换线色，不加底色不加图标轰炸）。
/// 支持字数计数（写信 ≤800 的场景）。
class NatsuInput extends StatefulWidget {
  const NatsuInput({
    super.key,
    this.controller,
    this.hint,
    this.maxLength,
    this.showError = false,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController? controller;

  /// 占位文字（ゴシック灰）。
  final String? hint;

  /// 字数上限；非 null 时右下角显示 `n / max`（写信=800）。
  final int? maxLength;

  /// 错误态：输入线变朱。错误文案由外层负责（输入框保持克制）。
  final bool showError;

  final bool enabled;
  final int maxLines;

  final ValueChanged<String>? onChanged;

  @override
  State<NatsuInput> createState() => _NatsuInputState();
}

class _NatsuInputState extends State<NatsuInput> {
  late final TextEditingController _ownController;
  TextEditingController get _controller =>
      widget.controller ?? _ownController;

  @override
  void initState() {
    super.initState();
    _ownController = TextEditingController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: widget.enabled,
      onFocusChange: (_) => setState(() {}),
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        final lineColor = !widget.enabled
            ? NatsuColors.paperEdge
            : widget.showError
                ? NatsuColors.error
                : focused
                    ? NatsuColors.focusRing
                    : NatsuBorders.inputSide.color;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: NatsuMotion.medium,
              curve: NatsuMotion.easing,
              constraints:
                  const BoxConstraints(minHeight: NatsuSpacing.inputHeight),
              padding: const EdgeInsets.symmetric(
                horizontal: NatsuSpacing.md,
                vertical: NatsuSpacing.sm,
              ),
              decoration: BoxDecoration(
                color:
                    widget.enabled ? NatsuColors.paperWhite : NatsuColors.envelope,
                borderRadius: BorderRadius.circular(NatsuRadius.card),
                border: Border.all(
                  color: lineColor,
                  width: focused ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: widget.enabled,
                      maxLines: widget.maxLines,
                      minLines: widget.maxLines == 1 ? 1 : null,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      style: NatsuTypography.body,
                      onChanged: widget.onChanged,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: widget.hint,
                        hintStyle: NatsuTypography.body.copyWith(
                          color: NatsuColors.inkFaint,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.maxLength != null) ...[
              const SizedBox(height: NatsuSpacing.xs),
              Text(
                '${_controller.text.characters.length} / ${widget.maxLength}',
                style: NatsuTypography.caption.copyWith(
                  color: widget.showError ? NatsuColors.error : null,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
