/// 漂流页固定底部操作栏：开信 | 换一封。
///
/// 每屏至多一个 primary——「开信」是仪式的主行动，「换一封」居次。
/// 两枚等宽双列，视觉居中平衡（短标签固定文案，无溢出风险）。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../../app/theme.dart';

class DriftActionBar extends StatelessWidget {
  const DriftActionBar({
    required this.busy,
    required this.onOpen,
    required this.onSwap,
    super.key,
  });

  /// 换一封进行中：两个按钮一起禁用，避免连点抽空脚本。
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: KazeColors.iconWell, width: 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KazeSpacing.md,
            vertical: KazeSpacing.sm,
          ),
          // 等宽双列：两枚按钮各占一半，标签居中（沿写信页寄出按钮的
          // Row(min, center) 子组件先例，拉宽时文字保持居中不左偏）
          child: Row(
            children: [
              Expanded(
                child: NatsuButton(
                  variant: NatsuButtonVariant.primary,
                  onPressed: busy ? null : onOpen,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [Text('开信')],
                  ),
                ),
              ),
              const SizedBox(width: KazeSpacing.sm),
              Expanded(
                child: NatsuButton(
                  variant: NatsuButtonVariant.secondary,
                  onPressed: busy ? null : onSwap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [Text('换一封')],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
