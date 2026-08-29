/// 概览 Dashboard：状态分布 / 池健康 / 待办直达。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/models/admin.dart';
import 'stats_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(statsControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsControllerProvider);
    final stats = state.stats;

    return Scaffold(
      appBar: AppBar(title: const Text('概览')),
      body: switch (state.phase) {
        StatsPhase.loading => const Center(child: CircularProgressIndicator()),
        StatsPhase.error => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('统计数据加载失败'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.read(statsControllerProvider.notifier).refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        StatsPhase.ready when stats == null => const SizedBox.shrink(),
        StatsPhase.ready => _ReadyBody(stats: stats!),
      },
    );
  }
}

class _ReadyBody extends ConsumerWidget {
  const _ReadyBody({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TodoCard(
              title: '待审核信件',
              count: stats.todo.pendingLetters,
              route: AdminRoutes.review,
            ),
            const SizedBox(width: 16),
            _TodoCard(
              title: '待处理举报',
              count: stats.todo.openReports,
              route: AdminRoutes.reports,
            ),
            const SizedBox(width: 16),
            _TodoCard(
              title: '未解决反馈',
              count: stats.todo.openFeedbacks,
              route: AdminRoutes.feedback,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('信件', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(
                      label: '待审核',
                      value: stats.lettersByStatus['pending'] ?? 0,
                    ),
                    _Metric(
                      label: '公开',
                      value: stats.lettersByStatus['public'] ?? 0,
                    ),
                    _Metric(
                      label: '已驳回',
                      value: stats.lettersByStatus['rejected'] ?? 0,
                    ),
                    _Metric(
                      label: '已下架',
                      value: stats.lettersByStatus['taken_down'] ?? 0,
                    ),
                    _Metric(label: '用户数', value: stats.usersTotal),
                    _Metric(label: '7 日新增', value: stats.letters7d),
                    _Metric(label: '30 日新增', value: stats.letters30d),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('池健康度', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(label: '漂流池可抽', value: stats.pool.driftAvailable),
                    _Metric(label: '就地公开', value: stats.pool.stayActive),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.title,
    required this.count,
    required this.route,
  });

  final String title;
  final int count;
  final String route;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: count > 0
                        ? scheme.tertiary.withValues(alpha: 0.12)
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: count > 0
                          ? scheme.tertiary
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
