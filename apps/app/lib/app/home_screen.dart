/// 首页 — 按画布「风信 App UI · 夏の手紙 v2」Screen/Home 实现。
///
/// 结构：透明 AppBar（仅汉堡菜单，右侧留白保持干净）+ 问候语/环境行 +
/// 三张入口卡（随机漂流/就地发掘/写一封信）+ 左侧抽屉导航。
/// 环境是夏日天空（渐变），纸只在「信」的时候出现 —— 入口卡是描边的
/// 透明卡，让天空透过来。
///
/// 环境行「地点 · 时段 · 天气」降级纪律：时段恒显示（本地时钟推导）；
/// 地点/天气等后端逆地理与天气服务可用后再补芯片。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../core/day_period.dart';
import 'controllers/home_environment_controller.dart';
import 'controllers/unread_count_controller.dart';
import 'router.dart';
import 'theme.dart';
import 'widgets/kaze_sky_box.dart';

class HomeScreen extends ConsumerWidget {
  HomeScreen({super.key, DateTime? now}) : now = now ?? DateTime.now();

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KazeSkyBox(
      // 环境是夏日天空，纸只在「信」的时候出现 —— 天色随当地天气×时段联动
      child: Scaffold(
        // 透明底让渐变从 body 一直透到 AppBar 之下
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: KazeHomeDims.appBarH,
          // 右上角刻意不放品牌字样，保持干净。
          // 设置了 drawer 后 AppBar 自动配汉堡钮（Icons.menu）。
        ),
        drawer: const _HomeDrawer(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KazeSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TitleSection(now: now),
                    SizedBox(height: KazeSpacing.xl),
                    const _CardsSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 问候语 + 引导语 + 环境行。
class _TitleSection extends ConsumerWidget {
  const _TitleSection({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final period = dayPeriodOf(now);
    final envState = ref.watch(homeEnvironmentControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greetingFor(period), style: theme.textTheme.headlineSmall),
        const SizedBox(height: KazeSpacing.sm),
        Text('把此刻写下来，寄给远方', style: theme.textTheme.bodyMedium),
        const SizedBox(height: KazeSpacing.sm),
        _EnvironmentRow(period: period, envState: envState),
      ],
    );
  }
}

// ---------- 天气 icon 映射 ----------

IconData _weatherIconFor(String? icon) {
  switch (icon) {
    case 'rainy':
      return Icons.water_drop_outlined;
    case 'cloudy':
      return Icons.cloud_outlined;
    case 'snowy':
      return Icons.ac_unit_outlined;
    case 'windy':
      return Icons.air_outlined;
    case 'foggy':
      return Icons.blur_on_outlined;
    case 'thunder':
      return Icons.flash_on_outlined;
    case 'sunny':
    default:
      return Icons.wb_sunny_outlined;
  }
}

/// 环境行：地点 · 时段 · 天气。
///
/// 地点/天气芯片在数据未就绪或后端降级时隐藏，仅时段芯片恒显示；
/// 芯片间以 3px 小圆点分隔。
class _EnvironmentRow extends StatelessWidget {
  const _EnvironmentRow({required this.period, this.envState});

  final KazeDayPeriod period;
  final HomeEnvironmentState? envState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final periodIcon = switch (period) {
      // 珊瑚色配给：时段图标属「旅行标记」语义
      KazeDayPeriod.morning => Icons.wb_twilight,
      KazeDayPeriod.noon => Icons.wb_sunny,
      KazeDayPeriod.evening => Icons.wb_twilight,
      KazeDayPeriod.night => Icons.nights_stay_outlined,
    };

    // 地点芯片（leaf 色）：placeLabel 非空时显示
    final placeChip = envState?.placeLabel != null
        ? _EnvChip(
            icon: Icons.location_on_outlined,
            label: envState!.placeLabel!,
            iconColor: KazeColors.leaf,
          )
        : null;

    // 天气芯片（sunlightYellow 色）：weather 非空时显示，仅展示描述文本，不含温度
    final weatherChip = envState?.weather != null
        ? _EnvChip(
            icon: _weatherIconFor(envState!.weather!.icon),
            label: envState!.weather!.text,
            iconColor: NatsuColors.sunlightYellow,
          )
        : null;

    // 时段芯片（coral 色）：恒显示
    final periodChip = _EnvChip(
      icon: periodIcon,
      label: dayPeriodLabel(period),
      iconColor: theme.colorScheme.tertiary,
    );

    // 分隔符：窄竖线 + 两侧留白，避免与 icon 视觉粘连
    Widget separator() => const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 2),
        VerticalDivider(thickness: 1, width: 5),
        SizedBox(width: 2),
      ],
    );

    final chips = <Widget>[];
    var hasPrev = false;

    if (placeChip != null) {
      chips.add(placeChip);
      hasPrev = true;
    }
    if (hasPrev || weatherChip != null) {
      if (hasPrev) chips.add(separator());
      chips.add(weatherChip!);
      hasPrev = true;
    }
    if (hasPrev) chips.add(separator());
    chips.add(periodChip);

    return Row(mainAxisSize: MainAxisSize.min, children: chips);
  }
}

/// 单个环境信息芯片：图标 + 标签。
class _EnvChip extends StatelessWidget {
  const _EnvChip({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: KazeSpacing.xs + 1),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

/// 三张入口卡：两条收信入口（并列的一等公民）+ 写信。
class _CardsSection extends StatelessWidget {
  const _CardsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HomeEntryCard(
          icon: Icons.air,
          title: '随机漂流',
          description: '抽一封陌生人漂来的信',
          onTap: () => context.push(Routes.drift),
        ),
        const SizedBox(height: KazeSpacing.sm + KazeSpacing.xs),
        _HomeEntryCard(
          icon: Icons.location_on_outlined,
          title: '就地发掘',
          description: '发现埋在此地的信',
          onTap: () => context.push(Routes.discover),
        ),
        const SizedBox(height: KazeSpacing.sm + KazeSpacing.xs),
        _HomeEntryCard(
          icon: Icons.edit,
          title: '写一封信',
          description: '把此刻写下来，寄给远方',
          onTap: () => context.push(Routes.write),
        ),
      ],
    );
  }
}

/// 透明入口卡：paperEdge 描边 + skyTop 35% 图标井，天空透出卡面。
class _HomeEntryCard extends StatelessWidget {
  const _HomeEntryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      // 暖白纸面底：与页面天空渐变形成冷暖对比
      color: NatsuColors.envelope,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // 方形小圆角波纹，与卡形一致
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KazeRadius.card),
        ),
        child: SizedBox(
          height: KazeHomeDims.cardH,
          child: Padding(
            // 16 内边距：88h − 32 = 56h 文字区，恰好容 16pt 标题 + 4 空 + 13pt 描述
            // （行高 28+4+20=52；画布内边距 20 会溢出 4px，记录偏差）
            padding: const EdgeInsets.all(KazeSpacing.md),
            child: Row(
              children: [
                Container(
                  width: KazeHomeDims.iconWell,
                  height: KazeHomeDims.iconWell,
                  decoration: BoxDecoration(
                    color: KazeColors.iconWell,
                    borderRadius: BorderRadius.circular(KazeRadius.card),
                  ),
                  child: Icon(
                    icon,
                    size: KazeHomeDims.entryIcon,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: KazeSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: KazeSpacing.xs),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KazeColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 左侧抽屉：品牌区 + 「我的」导航 + 关于。
///
/// 底部刻意不放任何文本（用户决定，保持干净）。
/// 「回信告知」的未读圆标只**消费** UnreadCountController——
/// 计数的拉取与增减都归该控制器所有（F5 状态唯一所有权）。
class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadCount = ref.watch(unreadCountControllerProvider);

    return SizedBox(
      width: KazeHomeDims.drawerW,
      child: Drawer(
        // 与首页同一天空渐变（用户决定；环境是天空，抽屉是天空的一部分）
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: KazeSkyBox(
          // 与首页同一天空（用户决定；环境是天空，抽屉是天空的一部分）
          // —— watch 同一全局天色，随主屏同步过渡
          // 透明 Material：给 InkWell 提供绘制墨水的表面。没有它，
          // 波纹会画在 Drawer 自带的 Material 上、被这层渐变盖住。
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              right: false,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KazeSpacing.lg,
                      KazeSpacing.lg,
                      KazeSpacing.lg,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('风信', style: theme.textTheme.titleLarge),
                        const SizedBox(height: KazeSpacing.xs),
                        Text('让作品先于作者抵达', style: theme.textTheme.labelMedium),
                        const SizedBox(height: KazeSpacing.xl),
                        Text('我的', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.mail_outline,
                    label: '我的信',
                    onTap: () => _push(context, Routes.myLetters),
                  ),
                  _DrawerItem(
                    icon: Icons.bookmark_border,
                    label: '抄本',
                    onTap: () => _push(context, Routes.scripbook),
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_none,
                    label: '回信告知',
                    trailing: unreadCount > 0
                        ? _UnreadBadge(count: unreadCount)
                        : null,
                    onTap: () => _push(context, Routes.notifications),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    onTap: () => _push(context, Routes.settings),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: KazeSpacing.lg),
                    child: Divider(),
                  ),
                  _DrawerItem(
                    icon: Icons.info_outline,
                    label: '关于风信',
                    onTap: () => _push(context, Routes.about),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 先收抽屉再跳转 — 返回时抽屉不应还开着。
  void _push(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.push(location);
  }
}

/// 未读数字圆标：一位数画正圆；两位数起横向展成胶囊（契约上限 50，
/// 两位数封顶）。珊瑚印章底 + 反色数字。
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final singleDigit = count < 10;
    return Container(
      height: KazeHomeDims.badgeDiameter,
      padding: EdgeInsets.symmetric(
        horizontal: singleDigit ? 0 : KazeSpacing.sm,
      ),
      constraints: BoxConstraints(
        minWidth: singleDigit
            ? KazeHomeDims.badgeDiameter
            : KazeHomeDims.badgePillMinW,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary,
        shape: singleDigit ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: singleDigit
            ? null
            : BorderRadius.circular(KazeHomeDims.badgeRadius),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiary,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;

  /// 行尾插槽（未读数圆标等）；空则不占位。
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: KazeHomeDims.drawerRowH,
      child: InkWell(
        onTap: onTap,
        // 方形小圆角波纹（本项目设计不使用完整圆形）
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KazeRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KazeSpacing.lg),
          child: Row(
            children: [
              Icon(
                icon,
                size: KazeHomeDims.drawerIcon,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: KazeSpacing.sm + KazeSpacing.xs),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
