/// 读信页空态：信不在了（404）或没能加载（网络/服务）。
///
/// 透明底手写体浮在信件天色上（沿 drift 首幕 / NarrativeCard 同范式）：
/// 主副两行文案 + 一个可选动作（再试一次）。返回走 AppBar 的返回键，
/// 不占版面位置。404 与网络错误共用这个壳，文案由调用方给；
/// 外层已垂直居中（KazeScaffold scrollable=false）。
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
    // 与 NarrativeCard/_DrawIntro 同款：手写体 22/36 标题 + hwNote 副文案
    final titleStyle = KazeLetterType.warmBody.copyWith(
      fontSize: 22,
      height: 36 / 22,
    );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: titleStyle, textAlign: TextAlign.center),
          const SizedBox(height: KazeSpacing.md),
          Text(
            subtitle,
            style: KazeLetterType.hwNote,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: KazeSpacing.xl),
            NatsuButton(
              variant: NatsuButtonVariant.primary,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
