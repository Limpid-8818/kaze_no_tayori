/// 信件摘要卡 —— 发掘列表 / 我的信 / 抄本共用的列表卡（F4 先接发掘）。
///
/// 跨 feature 复用件按根 CLAUDE.md §1 应上游化进设计系统包；同步前暂放
/// app/widgets，已记入 packages/natsu_no_tegami/COPY_IN.md 待上游化清单。
///
/// 视觉沿画布 Screen/Discover 的 LetterCard（暖白纸 + 发丝线 + r6），
/// 但按用户裁决不实现 ±1° 歪斜。内容区二选一：
/// - 有 AI 短诗 → 俳句排版：逐行 quoteSerif 衬线，最多三行（第四行截断省略）；
/// - 无诗 → 正文前两行预览（手写体小档）。
///
/// meta 行左侧是「位置信息槽」：后端因匿名铁律暂不下发距离，当前由
/// 地点名占位；`distanceLabel` 已预留，后端补字段后 mapper 一处接线。
/// 偏差记录：画布 meta 字号 11 → 令牌 labelMedium 13；内边距 18/16、
/// 行距 10 → 最近刻度 md/sm。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class LetterSummaryCard extends StatelessWidget {
  const LetterSummaryCard({
    required this.timeLabel,
    this.poem,
    this.previewText,
    this.placeLabel,
    this.distanceLabel,
    this.onTap,
    super.key,
  });

  final String timeLabel;

  /// AI 短诗原文（\n 分行）；null 或空 = 无诗走预览。
  final String? poem;

  /// 正文预览摘录（无诗时的回退位）。
  final String? previewText;

  /// 地点名（现阶段位置信息槽的占位内容）。
  final String? placeLabel;

  /// 距离（如「230m」）——后端补齐 discover 距离字段后接线。
  final String? distanceLabel;

  final VoidCallback? onTap;

  /// 俳句展示上限：三行诗形态。
  static const int _maxPoemLines = 3;

  List<String> get _poemLines => (poem ?? '')
      .trim()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(KazeRadius.card);
    return Container(
      decoration: BoxDecoration(
        color: KazeColors.envelope,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KazeSpacing.md,
              vertical: KazeSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMetaRow(theme),
                const SizedBox(height: KazeSpacing.sm),
                _buildBody(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(ThemeData theme) {
    final metaStyle = theme.textTheme.labelMedium?.copyWith(
      color: KazeColors.inkFaint,
    );
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (distanceLabel != null) ...[
                Icon(Icons.my_location, size: 12, color: KazeColors.inkFaint),
                const SizedBox(width: KazeSpacing.xs),
                Text(distanceLabel!, style: metaStyle),
              ],
              if (placeLabel != null && placeLabel!.isNotEmpty) ...[
                if (distanceLabel != null)
                  const SizedBox(width: KazeSpacing.sm),
                Expanded(
                  child: Text(
                    placeLabel!,
                    style: metaStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        // 时间贴右：Expanded 吸收全部剩余空间，时间用普通子节点收在行尾
        // （此前 Flexible 会与 Expanded 平分空间，标签悬在半程）
        Text(timeLabel, style: metaStyle),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    final lines = _poemLines;
    if (lines.isNotEmpty) {
      final truncated = lines.length > _maxPoemLines;
      final visible = truncated ? lines.sublist(0, _maxPoemLines) : lines;
      // 画布未定义卡片短诗样式；俳句按系统唯一衬线（quoteSerif，
      // AI 短诗专用令牌）逐行排——三行诗的行独立存在，长出的行以
      // 中文省略号收尾而不是在末行内部截断。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, line) in visible.indexed)
            Text(
              truncated && index == visible.length - 1 ? '$line……' : line,
              style: KazeLetterType.poem,
            ),
        ],
      );
    }
    final preview = previewText;
    if (preview == null || preview.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    // 画布预览为手写体 15/22；warmBody(hwBody 20) 最近档缩放至此（偏差记录）
    return Text(
      preview.trim(),
      style: KazeLetterType.warmBody.copyWith(fontSize: 15, height: 22 / 15),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
