/// 视图切换胶囊 —— 「信纸 ↔ 封筒」原地切换的开关（写信页/读信页共用）。
///
/// 文字胶囊：暖白纸底 + 发丝线 + 全圆角（Stadium），左上工具栏位的
/// 低强调控件——不是主行动，不抢寄出/回信的 primary 配给。图标与文案
/// 递出的是「切过去能看到什么」：看信纸时递出封筒图标 +「看封筒」，
/// 看封筒时递出纸页图标 +「回到信纸」。
///
/// 跨 feature 复用件按根 CLAUDE.md §1 应上游化进设计系统包；同步前暂放
/// app/widgets，已记入 packages/natsu_no_tegami/COPY_IN.md 待上游化清单。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class KazeViewToggle extends StatelessWidget {
  const KazeViewToggle({
    required this.envelopeShown,
    required this.onToggle,
    super.key,
  });

  /// 当前是否封筒态——决定按钮递出的方向与文案。
  final bool envelopeShown;

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: KazeColors.envelope,
      shape: StadiumBorder(side: BorderSide(color: theme.colorScheme.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KazeSpacing.md,
            vertical: KazeSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                envelopeShown ? Icons.description : Icons.mail_outline,
                size: 16,
                color: KazeColors.inkSoft,
              ),
              const SizedBox(width: KazeSpacing.xs),
              Text(
                envelopeShown ? '回到信纸' : '看封筒',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
