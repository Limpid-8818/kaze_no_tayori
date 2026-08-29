/// 工作台壳：左侧导航 + 待办角标。
///
/// 导航项为自绘全行 InkWell（CLAUDE 纪律：不手写字面量色/字号/间距，
/// 一律走 Theme/与 token 同源的 AdminTheme）——NavigationRail 的 M3
/// 指示胶囊只包 icon，label 是独立可点区域，视觉反馈与点击热区割裂，
/// 故不用它。选中 = 整行底色 pill；涟漪 = 整行。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'admin_auth.dart';
import 'theme.dart';
import '../data/models/admin.dart' show AdminTodo;
import '../data/models/enums.dart';
import '../features/dashboard/stats_controller.dart';

class _NavItem {
  const _NavItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.count,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// 角标取值（来自 stats.todo）；null = 无角标逻辑。
  final int? Function(AdminTodo todo)? count;
}

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  static final _items = <_NavItem>[
    const _NavItem(
      route: AdminRoutes.dashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: '概览',
    ),
    _NavItem(
      route: AdminRoutes.review,
      icon: Icons.pending_actions_outlined,
      selectedIcon: Icons.pending_actions,
      label: '审核队列',
      count: (t) => t.pendingLetters > 0 ? t.pendingLetters : null,
    ),
    const _NavItem(
      route: AdminRoutes.letters,
      icon: Icons.mail_outline,
      selectedIcon: Icons.mail,
      label: '信件管理',
    ),
    _NavItem(
      route: AdminRoutes.reports,
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag,
      label: '举报处理',
      count: (t) => t.openReports > 0 ? t.openReports : null,
    ),
    _NavItem(
      route: AdminRoutes.feedback,
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum,
      label: '反馈管理',
      count: (t) => t.openFeedbacks > 0 ? t.openFeedbacks : null,
    ),
    const _NavItem(
      route: AdminRoutes.seed,
      icon: Icons.outbox_outlined,
      selectedIcon: Icons.outbox,
      label: '种子信件',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(statsControllerProvider.notifier).start();
    });
  }

  int _indexOf(String location) {
    if (location.startsWith(AdminRoutes.review)) return 1;
    if (location.startsWith(AdminRoutes.letters)) return 2;
    if (location.startsWith(AdminRoutes.reports)) return 3;
    if (location.startsWith(AdminRoutes.feedback)) return 4;
    if (location.startsWith(AdminRoutes.seed)) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexOf(location);
    final stats = ref.watch(statsControllerProvider).stats;
    final todo = stats?.todo;
    final extended = MediaQuery.widthOf(context) >= 1100;

    return Scaffold(
      body: Row(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SizedBox(
              width: extended ? 200 : 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Text(
                      '风信 · 控制台',
                      maxLines: extended ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: extended ? TextAlign.start : TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: SizedBox(
                      height: 36,
                      child: TextButton.icon(
                        onPressed: () async {
                          await ref.read(adminAuthProvider).signOut();
                        },
                        icon: const Icon(Icons.logout, size: 16),
                        label: extended
                            ? const Text('退出')
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  for (var i = 0; i < _items.length; i++)
                    _NavTile(
                      item: _items[i],
                      selected: i == index,
                      extended: extended,
                      badgeCount: _items[i].count == null || todo == null
                          ? null
                          : _items[i].count!(todo),
                      onTap: () => _go(context, i),
                    ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  void _go(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go(AdminRoutes.dashboard);
      case 1:
        context.go(AdminRoutes.review);
      case 2:
        context.go(AdminRoutes.letters);
      case 3:
        context.go(AdminRoutes.reports);
      case 4:
        context.go(AdminRoutes.feedback);
      case 5:
        context.go(AdminRoutes.seed);
    }
  }
}

/// 全行导航项：整行涟漪 + 整行选中底色，点击热区与视觉反馈一致。
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.badgeCount,
  });

  final _NavItem item;
  final bool selected;
  final bool extended;
  final int? badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;

    final content = Row(
      children: [
        const SizedBox(width: 20),
        _BadgeIcon(
          icon: selected ? item.selectedIcon : item.icon,
          count: badgeCount,
          color: foreground,
        ),
        if (extended) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        // 选中底色 pill（与涟漪同域，热区 = 整行）
        color: selected ? scheme.surfaceContainerLow : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerLeft,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// 带待办角标的导航图标。
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, this.count, this.color});

  final IconData icon;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(this.icon, color: color);
    if (count == null) return icon;
    return Badge(
      label: Text('$count'),
      isLabelVisible: true,
      backgroundColor: AdminTheme.statusColor(LetterStatus.pending),
      child: icon,
    );
  }
}
