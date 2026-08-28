/// 胶囊动作钮 —— 工具行里的低强调次级入口（跳转/触发，无状态翻转）。
///
/// 视觉规格与 [KazeViewToggle] 同源：暖白纸底 + 发丝线 + Stadium 全圆角，
/// 16px 图标 + labelSmall 文案——不是主行动，不抢寄出/回信的 primary
/// 配给。带「切过去能看到什么」语义的开关用 KazeViewToggle，纯动作用本件。
///
/// 跨 feature 复用件按根 CLAUDE.md §1 应上游化进设计系统包；同步前暂放
/// app/widgets，已记入 packages/natsu_no_tegami/COPY_IN.md 待上游化清单。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class KazePillAction extends StatelessWidget {
  const KazePillAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: KazeColors.envelope,
      shape: StadiumBorder(side: BorderSide(color: theme.colorScheme.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KazeSpacing.md,
            vertical: KazeSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: KazeColors.inkSoft),
              const SizedBox(width: KazeSpacing.xs),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
