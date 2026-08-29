/// 反馈管理：复用现有 /v1/admin/feedbacks 端点（筛选/备注/流转）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/admin.dart';
import '../../data/models/enums.dart';
import '../../shared/widgets.dart' show showNotice;

enum FeedbackPhase { loading, ready, empty, error }

class FeedbackState {
  const FeedbackState({
    this.phase = FeedbackPhase.loading,
    this.items = const [],
    this.categoryFilter,
    this.showResolved = false,
    this.notice,
  });

  final FeedbackPhase phase;
  final List<AdminFeedback> items;
  final FeedbackCategory? categoryFilter;
  final bool showResolved;
  final ({String message, int seq})? notice;

  FeedbackState copyWith({
    FeedbackPhase? phase,
    List<AdminFeedback>? items,
    FeedbackCategory? categoryFilter,
    bool? showResolved,
    ({String message, int seq})? notice,
  }) => FeedbackState(
    phase: phase ?? this.phase,
    items: items ?? this.items,
    categoryFilter: categoryFilter ?? this.categoryFilter,
    showResolved: showResolved ?? this.showResolved,
    notice: notice,
  );
}

class FeedbackController extends Notifier<FeedbackState> {
  int _noticeSeq = 0;

  @override
  FeedbackState build() => const FeedbackState();

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
  }

  Future<void> toggleShowResolved() async {
    state = state.copyWith(showResolved: !state.showResolved);
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
          .feedbacks(
            status: state.showResolved ? null : FeedbackStatus.open,
            category: state.categoryFilter,
          );
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: page.items.isEmpty ? FeedbackPhase.empty : FeedbackPhase.ready,
        items: page.items,
      );
    } on ApiFailure {
      if (!ref.mounted) return;
      state = state.copyWith(phase: FeedbackPhase.error);
    }
  }

  Future<void> setCategory(FeedbackCategory? category) async {
    // 显式构造：copyWith 的 `?? this` 会把 null 当「不改」吞掉，「只看问题」取消不了
    state = FeedbackState(
      phase: state.phase,
      items: state.items,
      categoryFilter: category,
      showResolved: state.showResolved,
    );
    await refresh();
  }

  Future<void> setNote(String id, String note) async {
    try {
      await ref.read(adminApiProvider).updateFeedback(id, adminNote: note);
      _notify('备注已保存');
      await refresh();
    } on ApiFailure catch (e) {
      _notify(e.message);
    }
  }

  Future<void> setStatus(String id, FeedbackStatus status) async {
    try {
      await ref.read(adminApiProvider).updateFeedback(id, status: status);
      _notify(status == FeedbackStatus.resolved ? '已标记已处理' : '已回退待处理');
      await refresh();
    } on ApiFailure catch (e) {
      _notify(e.message);
    }
  }
}

final feedbackControllerProvider =
    NotifierProvider<FeedbackController, FeedbackState>(FeedbackController.new);

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedbackControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedbackControllerProvider);

    ref.listen<FeedbackState>(feedbackControllerProvider, (prev, next) {
      final n = next.notice;
      if (n != null && prev?.notice?.seq != n.seq) {
        showNotice(context, n.message);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('反馈管理')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilterChip(
                  selected: state.showResolved,
                  label: const Text('显示已处理'),
                  onSelected: (_) => ref
                      .read(feedbackControllerProvider.notifier)
                      .toggleShowResolved(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: state.categoryFilter == FeedbackCategory.bug,
                  label: const Text('只看问题'),
                  onSelected: (_) => ref
                      .read(feedbackControllerProvider.notifier)
                      .setCategory(
                        state.categoryFilter == null
                            ? FeedbackCategory.bug
                            : null,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (state.phase) {
                FeedbackPhase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                FeedbackPhase.empty => const Center(child: Text('暂无反馈')),
                FeedbackPhase.error => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('列表加载失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref
                            .read(feedbackControllerProvider.notifier)
                            .refresh(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
                FeedbackPhase.ready => ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, i) =>
                      _FeedbackCard(feedback: state.items[i]),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends ConsumerWidget {
  const _FeedbackCard({required this.feedback});

  final AdminFeedback feedback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(feedbackControllerProvider.notifier);
    final resolved = feedback.status == FeedbackStatus.resolved;

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
                  feedback.category == FeedbackCategory.bug ? '问题' : '建议',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '${feedback.appVersion ?? '?'} · ${feedback.platform ?? '?'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  resolved ? '已处理' : '待处理',
                  style: TextStyle(
                    color: resolved
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(feedback.content),
            if (feedback.adminNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '备注：${feedback.adminNote}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final note = await _editNote(context, feedback.adminNote);
                    if (note != null) {
                      await controller.setNote(feedback.id, note);
                    }
                  },
                  child: const Text('备注'),
                ),
                const SizedBox(width: 8),
                if (!resolved)
                  FilledButton(
                    onPressed: () => controller.setStatus(
                      feedback.id,
                      FeedbackStatus.resolved,
                    ),
                    child: const Text('标记已处理'),
                  )
                else
                  OutlinedButton(
                    onPressed: () =>
                        controller.setStatus(feedback.id, FeedbackStatus.open),
                    child: const Text('回退待处理'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _editNote(BuildContext context, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('管理备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '内部备注，不影响用户侧'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    return result;
  }
}
