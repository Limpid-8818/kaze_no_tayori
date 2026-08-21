import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 对话框 — 浮起的纸
///
/// Dialog 是被拈起的纸面（与 NatsuCard 同层，非内联骨架）：paperHover 阴影、
/// 发丝线、纸白面。标题墨蓝 heading，正文次级墨，行动区由调用方传
/// `NatsuButton ghost/primary sm`。入场 = fade + 0.96→1 微放大（medium）。
Future<T?> showNatsuDialog<T>({
  required BuildContext context,
  required Widget title,
  Widget? body,
  List<Widget> actions = const <Widget>[],
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '关闭',
    barrierColor: NatsuColors.scrim,
    transitionDuration: NatsuMotion.medium,
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: NatsuMotion.easing);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondary) => NatsuDialog(
      title: title,
      body: body,
      actions: actions,
    ),
  );
}

/// 对话框面 — 通常经 [showNatsuDialog] 弹出，不直接使用
class NatsuDialog extends StatelessWidget {
  const NatsuDialog({
    super.key,
    required this.title,
    this.body,
    this.actions = const <Widget>[],
  });

  final Widget title;
  final Widget? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        // 窄屏边距：对话框不顶到屏幕边
        padding: const EdgeInsets.symmetric(horizontal: NatsuSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: NatsuSpacing.dialogMaxW),
          child: DefaultTextStyle(
            // 纯 widgets 路由无 Material 祖先：环境默认样式是 debug 回退
            // （红字黄双下划线）。Text 的显式样式会与环境 merge——null 的
            // decoration 字段被回退样式填充。在这里切断，给浮层干净默认。
            style: NatsuTypography.body,
            child: Container(
            padding: const EdgeInsets.all(NatsuSpacing.lg),
            decoration: BoxDecoration(
              color: NatsuColors.paperWhite,
              borderRadius: BorderRadius.circular(NatsuRadius.card),
              border: NatsuBorders.hairline,
              boxShadow: NatsuShadows.paperHover,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DefaultTextStyle(
                  style: NatsuTypography.heading.copyWith(
                      color: NatsuColors.inkBlue),
                  child: title,
                ),
                if (body != null) ...[
                  const SizedBox(height: NatsuSpacing.md),
                  DefaultTextStyle(
                    style: NatsuTypography.bodySecondary
                        .copyWith(color: NatsuColors.inkSoft),
                    child: body!,
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: NatsuSpacing.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, action) in actions.indexed) ...[
                          if (i > 0) const SizedBox(width: NatsuSpacing.sm),
                          action,
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
