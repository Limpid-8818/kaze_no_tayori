/// 信件摘要卡 —— 发掘列表 / 我的信 / 抄本共用的列表卡（F4 先接发掘）。
///
/// 跨 feature 复用件按根 CLAUDE.md §1 应上游化进设计系统包；同步前暂放
/// app/widgets，已记入 packages/natsu_no_tegami/COPY_IN.md 待上游化清单。
///
/// 视觉沿画布 Screen/Discover 的 LetterCard（暖白纸 + 发丝线 + r6），
/// 但按用户裁决不实现 ±1° 歪斜。内容区正文预览为主位（前两行，手写体
/// 小档）；有 AI 短诗时在其下追加一行注记：三行诗以空格压成一行、
/// 缩号灰字，起注脚作用而不喧宾夺主。
///
/// meta 行左侧是「位置信息槽」：后端因匿名铁律暂不下发距离，当前由
/// 地点名占位；`distanceLabel` 已预留，后端补字段后 mapper 一处接线。
/// `statusLabel`（F6 我的信）贴右、时间左侧，用设计系统 NatsuTag(sm)
/// 呈现；F6 后续起启用语义色点 `statusDot`（状态徽标专用 6px 点，
/// 令牌 NatsuColors.status*），取代早前「状态不配点」的裁决——
/// 小面积点綴不伤配色纪律，反而让状态一眼可辨。参数保持纯字符串+可选色。
/// 偏差记录：画布 meta 字号 11 → 令牌 labelMedium 13；内边距 18/16、
/// 行距 10 → 最近刻度 md/sm。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../theme.dart';

class LetterSummaryCard extends StatelessWidget {
  const LetterSummaryCard({
    required this.timeLabel,
    this.poem,
    this.previewText,
    this.placeLabel,
    this.distanceLabel,
    this.statusLabel,
    this.statusDot,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final String timeLabel;

  /// AI 短诗原文（\n 分行）；null 或空 = 不渲染注记行。
  final String? poem;

  /// 正文预览摘录（卡片主位）。
  final String? previewText;

  /// 地点名（现阶段位置信息槽的占位内容）。
  final String? placeLabel;

  /// 距离（如「230m」）——后端补齐 discover 距离字段后接线。
  final String? distanceLabel;

  /// 状态徽标文案（我的信：审核中/公开/…）；null = 不渲染（发掘列表不受影响）。
  final String? statusLabel;

  /// 状态徽标语义色点（NatsuColors.status*）；null = 无点（纯文字徽标）。
  final Color? statusDot;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 诗注记行：多行诗以空格压成一行展示。
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
          onLongPress: onLongPress,
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
        // （此前 Flexible 会与 Expanded 平分空间，标签悬在半程）。
        // 状态徽标再往左一位（我的信），无 statusLabel 时整段不出现。
        if (statusLabel != null) ...[
          NatsuTag(label: statusLabel!, dot: statusDot, size: NatsuTagSize.sm),
          const SizedBox(width: KazeSpacing.sm),
        ],
        Text(timeLabel, style: metaStyle),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    // 画布预览为手写体 15/22；warmBody(hwBody 20) 最近档缩放至此（偏差记录）
    final previewStyle = KazeLetterType.warmBody.copyWith(
      fontSize: 15,
      height: 22 / 15,
    );
    // 诗注记：俳句按系统唯一衬线（quoteSerif，AI 短诗专用令牌）缩号转灰，
    // 多行以空格压成一行，作预览下方的注脚而非主内容。
    final poemNoteStyle = KazeLetterType.poem.copyWith(
      fontSize: 12,
      height: 16 / 12,
      color: KazeColors.inkFaint,
    );

    final preview = previewText?.trim();
    final hasPreview = preview != null && preview.isNotEmpty;
    final poemNote = _poemLines.join(' ');
    final hasPoemNote = poemNote.isNotEmpty;
    if (!hasPreview && !hasPoemNote) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasPreview)
          Text(
            preview,
            style: previewStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (hasPreview && hasPoemNote) const SizedBox(height: KazeSpacing.xs),
        if (hasPoemNote)
          Text(
            poemNote,
            style: poemNoteStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
