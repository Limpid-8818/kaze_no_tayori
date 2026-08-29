/// 审核队列：默认 pending 的列表 + 筛选。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../shared/widgets.dart' show showNotice;
import 'letter_list_controller.dart'
    show LetterListState, ListPhase, LetterSummaryRow, reviewListProvider;

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reviewListProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewListProvider);

    ref.listen<LetterListState>(reviewListProvider, (prev, next) {
      final n = next.notice;
      if (n != null && prev?.notice?.seq != n.seq) {
        showNotice(context, n.message);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('审核队列')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '队列只含待审核（pending）；通过 → 公开，驳回 → 终态（可赦免）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (state.phase) {
                ListPhase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                ListPhase.empty => const Center(child: Text('暂无待审核的信')),
                ListPhase.error => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('列表加载失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.read(reviewListProvider.notifier).refresh(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
                ListPhase.ready => ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, i) {
                    final item = state.items[i];
                    return LetterSummaryRow(
                      item: item,
                      onTap: () =>
                          context.go(AdminRoutes.reviewDetailOf(item.id)),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}
