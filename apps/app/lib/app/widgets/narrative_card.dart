/// 叙事状态卡 —— 池空/附近没信/加载失败这类「不是错误」的状态呈现。
///
/// 一张撑满内容宽的暖白纸卡 + 主副两行文案 + 可选动作。ReaderEmptyState
/// 与本卡同范式；新功能请直接用这张，旧的那张留在 reader 不动。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../theme.dart';

class NarrativeCard extends StatelessWidget {
  const NarrativeCard({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
    super.key,
  });

  final String title;
  final String subtitle;

  /// 动作文案；null = 无动作。
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 第二动作（如拒绝态的「去设置」）；与主动作并列一行。
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(KazeSpacing.xl),
      decoration: BoxDecoration(
        color: KazeColors.envelope,
        borderRadius: BorderRadius.circular(KazeRadius.card),
        boxShadow: KazeLetterShadows.resting,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KazeSpacing.md),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: KazeColors.inkFaint,
            ),
            textAlign: TextAlign.center,
          ),
          if (_hasPrimary && _hasSecondary) ...[
            const SizedBox(height: KazeSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: NatsuButton(
                    variant: NatsuButtonVariant.secondary,
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
                const SizedBox(width: KazeSpacing.sm),
                Expanded(
                  child: NatsuButton(
                    variant: NatsuButtonVariant.secondary,
                    onPressed: onSecondaryAction,
                    child: Text(secondaryLabel!),
                  ),
                ),
              ],
            ),
          ] else if (_hasPrimary) ...[
            const SizedBox(height: KazeSpacing.xl),
            NatsuButton(
              variant: NatsuButtonVariant.secondary,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasPrimary => actionLabel != null && onAction != null;
  bool get _hasSecondary => secondaryLabel != null && onSecondaryAction != null;
}
