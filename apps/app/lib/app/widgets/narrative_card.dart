/// 叙事状态 —— 池空/附近没信/加载失败这类「不是错误」的状态呈现。
///
/// 透明底手写体直接浮在天空渐变上（沿 drift 首幕 _DrawIntro 范式）：
/// 主副两行文案 + 可选动作，不再垫纸卡。ReaderEmptyState 与本范式
/// 同款；新功能请直接用这个，旧的那张留在 reader 不动。
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
    // 画布空态为手写体 22/36；warmBody(hwBody 20) 最近档放大至此（偏差记录，
    // 同 _DrawIntro）。副文案用 hwNote 手写小注，灰一档退后。
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
          if (_hasPrimary && _hasSecondary) ...[
            const SizedBox(height: KazeSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: NatsuButton(
                    variant: NatsuButtonVariant.primary,
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
              variant: NatsuButtonVariant.primary,
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
