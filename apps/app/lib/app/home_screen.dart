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
import 'package:go_router/go_router.dart';

import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../core/day_period.dart';
import 'router.dart';
import 'theme.dart';

class HomeScreen extends StatelessWidget {
  // 非 const 构造：now 默认取当前时间（非编译期常量）。
  HomeScreen({super.key, DateTime? now}) : now = now ?? DateTime.now();

  /// 时钟注入点 — 默认取当前时间，测试传固定值使问候语可断言。
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // 环境是夏日天空，纸只在「信」的时候出现
      decoration: const BoxDecoration(gradient: KazeTheme.skyGradient),
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
class _TitleSection extends StatelessWidget {
  const _TitleSection({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = dayPeriodOf(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greetingFor(period), style: theme.textTheme.headlineSmall),
        const SizedBox(height: KazeSpacing.sm),
        Text('把此刻写下来，寄给远方', style: theme.textTheme.bodyMedium),
        const SizedBox(height: KazeSpacing.sm),
        _EnvironmentRow(period: period),
      ],
    );
  }
}

/// 环境行：地点 · 时段 · 天气。
///
/// v1 只渲染时段芯片（恒可得的本地推导）；地点/天气芯片待后端
/// 逆地理与天气服务（现为可降级桩）可用后按下述槽位补入：
/// [地点 pin(leaf 色) + 地名] · [时段图标(coral) + 朝/昼/夕/夜] · [太阳 + 天气]，
/// 芯片间以 3px 小圆点分隔。
class _EnvironmentRow extends StatelessWidget {
  const _EnvironmentRow({required this.period});

  final KazeDayPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (period) {
      // 珊瑚色配给：时段图标属「旅行标记」语义
      KazeDayPeriod.morning => Icons.wb_twilight,
      KazeDayPeriod.noon => Icons.wb_sunny,
      KazeDayPeriod.evening => Icons.wb_twilight,
      KazeDayPeriod.night => Icons.nights_stay_outlined,
    };

    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.tertiary),
        const SizedBox(width: KazeSpacing.xs + 1),
        Text(dayPeriodLabel(period), style: theme.textTheme.labelMedium),
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
class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: KazeHomeDims.drawerW,
      child: Drawer(
        // 与首页同一天空渐变（用户决定；环境是天空，抽屉是天空的一部分）
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: KazeTheme.skyGradient),
          // 透明 Material：给 InkWell 提供绘制墨水的表面。没有它，
          // 波纹会画在 Drawer 自带的 Material 上、被这层渐变盖住。
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
              Text(label, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
