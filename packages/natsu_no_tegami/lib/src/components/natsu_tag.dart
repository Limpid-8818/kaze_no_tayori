import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 标签
///
/// 16px 药丸 + 发丝线。思绪标签（写信时选 1–3 个）的载体。
/// 语义点 [dot]：小面积点綴色——
/// skyBlue（场景·场所）/ sunlightYellow（情绪·感受）/ coralStamp（旅行标记）。
class NatsuTag extends StatelessWidget {
  const NatsuTag({
    super.key,
    required this.label,
    this.dot,
    this.size = NatsuTagSize.md,
    this.selected = false,
  });

  final String label;

  /// 语义点颜色；null 则无点。
  final Color? dot;

  final NatsuTagSize size;

  /// 选中态：墨底反白（标签选择器用）。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final small = size == NatsuTagSize.sm;
    final py = small ? 4.0 : NatsuSpacing.tagPaddingY;
    final px = small ? 12.0 : NatsuSpacing.tagPaddingX;
    final radius = small ? NatsuRadius.tagSm : NatsuRadius.tag;

    final bg = selected ? NatsuColors.skyBlue : NatsuColors.paperWhite;
    final fg = selected ? NatsuColors.onInk : NatsuColors.inkSoft;
    final border = selected ? NatsuColors.skyBlue : NatsuColors.paperEdge;

    return Container(
      padding: EdgeInsets.symmetric(vertical: py, horizontal: px),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? NatsuColors.onInk : dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: NatsuSpacing.sm),
          ],
          Text(
            label,
            style: small
                ? NatsuTypography.caption.copyWith(
                    color: fg,
                    letterSpacing: NatsuTypography.meta.letterSpacing,
                  )
                : NatsuTypography.label.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

enum NatsuTagSize { sm, md }
