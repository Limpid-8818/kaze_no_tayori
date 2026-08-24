/// 设置页行组件体系 — 按画布「夏の手紙 v2 · Screen/Settings」实现。
///
/// 三件套（新增设置项 = 往 [SettingsSection] 里加一行，不写布局）：
/// - [SettingsSection]：组标签（如「偏好」）+ 白纸卡片容器，行间自动插纸缘分隔线
/// - [SettingsSwitchTile]：开关行 — 图标 + 标题 + NatsuSwitch，整行命中即切换
/// - [SettingsNavTile]：导航行 — 图标 + 标题 + 当前值 + chevron（未来「主题皮肤」
///   「清除缓存」等行的骨架，本期设置页暂未使用）
///
/// 放在 lib/app/widgets/：跨 feature 复用的视觉组件（与 placeholder_screen 同级）。
/// 视觉一律走 Theme.of / KazeSpacing / KazeColors / KazeSettingsDims 速记，
/// 不写字面量颜色/字号/间距（见 apps/app/CLAUDE.md）。
library;

import 'package:flutter/material.dart';

import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../theme.dart';

/// 组标签 + 卡片容器。
///
/// 画布：标签与卡片左缘对齐（不缩进），标签下缘距卡片约 10px；
/// 卡片 = 白纸 + 纸缘描边 + rx6 + 零阴影（theme.cardTheme 已配）。
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.label, required this.tiles});

  /// 组标签，如「偏好」。
  final String label;

  /// 设置行。行与行之间自动插入全宽纸缘分隔线（dividerTheme = paperEdge）。
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: KazeSpacing.sm),
          child: Text(label, style: theme.textTheme.labelSmall),
        ),
        // 零内边距：行高/左右余白由行自管，分隔线才能贴卡缘全宽
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, tile) in tiles.indexed) ...[
                if (i > 0) const Divider(),
                tile,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 开关行：整行点击与拨动开关本体等效切换。
///
/// 点在开关上时由 NatsuSwitch 自身的命中区消费（不冒泡到行），
/// 两种手势都只翻转一次。
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.onChanged,
  });

  final IconData icon;
  final String title;

  /// 当前开关态
  final bool value;

  /// 切换回调；null 时整行与开关一并禁用
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: icon,
      title: title,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: NatsuSwitch(value: value, onChanged: onChanged),
    );
  }
}

/// 导航行：当前值 + chevron。值可空（无当前态的入口行只出 chevron）。
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.value,
  });

  final IconData icon;
  final String title;

  /// 右侧当前值（如「夏」/「12.6 MB」）
  final String? value;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsTile(
      icon: icon,
      title: title,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: KazeColors.inkFaint,
              ),
            ),
          Icon(
            Icons.chevron_right,
            size: KazeSettingsDims.tileIcon + KazeSpacing.xs,
            color: KazeColors.inkFaint,
          ),
        ],
      ),
    );
  }
}

/// 基础行 — 画布还原：高 53、图标 18（次级墨）、标题墨蓝、右缘留 16。
/// 图标到标题画布间距 14.75，取刻度 12（sm+xs，偏差记录于此）。
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: KazeSettingsDims.rowH,
      child: InkWell(
        onTap: onTap,
        // 方形小圆角波纹（本项目设计不使用完整圆形，同 Home 抽屉行）
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KazeRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KazeSpacing.md),
          child: Row(
            children: [
              Icon(
                icon,
                size: KazeSettingsDims.tileIcon,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: KazeSpacing.sm + KazeSpacing.xs),
              Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
