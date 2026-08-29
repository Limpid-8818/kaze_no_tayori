/// 举报处理：open 队列 + 处置（下架并 actioned / 驳回 dismissed）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/admin.dart';
import '../../data/models/enums.dart';
import '../../shared/widgets.dart' show confirmAction, showNotice;

enum ReportsPhase { loading, ready, empty, error }

class ReportsState {
  const ReportsState({
    this.phase = ReportsPhase.loading,
    this.items = const [],
    this.showHandled = false,
    this.notice,
  });

  final ReportsPhase phase;
  final List<AdminReport> items;
  final bool showHandled;
  final ({String message, int seq})? notice;

  ReportsState copyWith({
    ReportsPhase? phase,
    List<AdminReport>? items,
    bool? showHandled,
    ({String message, int seq})? notice,
  }) => ReportsState(
    phase: phase ?? this.phase,
    items: items ?? this.items,
    showHandled: showHandled ?? this.showHandled,
    notice: notice,
  );
}

class ReportsController extends Notifier<ReportsState> {
  int _noticeSeq = 0;

  @override
  ReportsState build() => const ReportsState();

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
  }

  Future<void> toggleShowHandled() async {
    state = state.copyWith(showHandled: !state.showHandled);
    await refresh();
  }

  void _notify(String message) {
    _noticeSeq += 1;
    state = state.copyWith(notice: (message: message, seq: _noticeSeq));
  }

  Future<void> refresh() async {
    try {
      final page = await ref
          .read(adminApiProvider)
          .reports(status: state.showHandled ? null : ReportStatus.open);
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: page.items.isEmpty ? ReportsPhase.empty : ReportsPhase.ready,
        items: page.items,
      );
    } on ApiFailure {
      if (!ref.mounted) return;
      state = state.copyWith(phase: ReportsPhase.error);
    }
  }

  /// 驳回举报（信件不动）。
  Future<void> dismiss(String reportId) async {
    await _update(reportId, ReportStatus.dismissed, '举报已驳回');
  }

  /// 下架涉事信并标记已处置。
  Future<void> takeDownAndAction(
    BuildContext context,
    AdminReport report,
  ) async {
    try {
      await ref
          .read(adminApiProvider)
          .transitionLetter(report.letter.id, LetterStatus.takenDown);
      await _update(report.id, ReportStatus.actioned, '信已下架，举报标记已处置');
    } on ApiFailure catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _update(String id, ReportStatus status, String message) async {
    try {
      await ref.read(adminApiProvider).updateReport(id, status: status);
      _notify(message);
      await refresh();
    } on ApiFailure catch (e) {
      _notify(e.message);
    }
  }
}

final reportsControllerProvider =
    NotifierProvider<ReportsController, ReportsState>(ReportsController.new);

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportsControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsControllerProvider);

    ref.listen<ReportsState>(reportsControllerProvider, (prev, next) {
      final n = next.notice;
      if (n != null && prev?.notice?.seq != n.seq) {
        showNotice(context, n.message);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('举报处理')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilterChip(
                  selected: state.showHandled,
                  label: const Text('显示已处理'),
                  onSelected: (_) => ref
                      .read(reportsControllerProvider.notifier)
                      .toggleShowHandled(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (state.phase) {
                ReportsPhase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                ReportsPhase.empty => const Center(child: Text('没有待处理的举报')),
                ReportsPhase.error => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('列表加载失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref
                            .read(reportsControllerProvider.notifier)
                            .refresh(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
                ReportsPhase.ready => ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, i) =>
                      _ReportCard(report: state.items[i]),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final handled = report.status != ReportStatus.open;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '理由：${report.reason}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                if (handled)
                  Text(
                    report.status == ReportStatus.actioned ? '已处置' : '已驳回',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                const Spacer(),
                Text(
                  '${report.createdAt.month}月${report.createdAt.day}日',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (report.detail != null && report.detail!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(report.detail!),
              ),
            const SizedBox(height: 8),
            Text(
              '涉事信：${report.letter.preview ?? '（纯照片信）'} · '
              '${report.letter.placeLabel ?? '无落点'} · ${switch (report.letter.status) {
                LetterStatus.pending => '待审核',
                LetterStatus.public => '公开中',
                LetterStatus.rejected => '已驳回',
                LetterStatus.takenDown => '已下架',
              }}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      context.go(AdminRoutes.reviewDetailOf(report.letter.id)),
                  child: const Text('查看信件'),
                ),
                const Spacer(),
                if (!handled) ...[
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await confirmAction(
                        context,
                        title: '驳回举报？',
                        message: '信件状态不变，仅把举报标记为驳回。',
                        confirmLabel: '驳回举报',
                      );
                      if (ok) {
                        await ref
                            .read(reportsControllerProvider.notifier)
                            .dismiss(report.id);
                      }
                    },
                    child: const Text('驳回'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onPrimary,
                    ),
                    onPressed: () async {
                      final ok = await confirmAction(
                        context,
                        title: '下架涉事信并标记已处置？',
                        message: '下架后读者侧立即 404（可恢复）。',
                        confirmLabel: '下架并处置',
                        destructive: true,
                      );
                      if (ok && context.mounted) {
                        await ref
                            .read(reportsControllerProvider.notifier)
                            .takeDownAndAction(context, report);
                      }
                    },
                    child: const Text('下架并处置'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
