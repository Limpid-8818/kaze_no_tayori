/// 读信页空态：信不在了（404）或没能加载（网络/服务）。
///
/// 一张撑满内容宽的纸白卡片 + 主副两行文案 + 一个可选动作（再试一次）。
/// 返回走 AppBar 的返回键，不占卡片位置。404 与网络错误共用这个壳，
/// 文案由调用方给；外层已垂直居中（KazeScaffold scrollable=false）。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../../app/theme.dart';

class ReaderEmptyState extends StatelessWidget {
  const ReaderEmptyState({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String subtitle;

  /// 动作按钮文案；null = 不显示（如 404，返回交给 AppBar）。
  final String? actionLabel;
  final VoidCallback? onAction;

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
          if (actionLabel != null && onAction != null) ...[
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
}
