/// 信件管理：全状态检索 + 下架/恢复/赦免。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../shared/widgets.dart' show showNotice, StatusFilterButton;
import '../review/letter_list_controller.dart'
    show LetterListState, ListPhase, LetterSummaryRow, lettersListProvider;

class LettersScreen extends ConsumerStatefulWidget {
  const LettersScreen({super.key});

  @override
  ConsumerState<LettersScreen> createState() => _LettersScreenState();
}

class _LettersScreenState extends ConsumerState<LettersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lettersListProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lettersListProvider);

    ref.listen<LetterListState>(lettersListProvider, (prev, next) {
      final n = next.notice;
      if (n != null && prev?.notice?.seq != n.seq) {
        showNotice(context, n.message);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('信件管理')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StatusFilterButton(
                  value: state.statusFilter,
                  onSelected: (s) =>
                      ref.read(lettersListProvider.notifier).setStatusFilter(s),
                ),
                const SizedBox(width: 8),
                _OwnerFilterButton(
                  value: state.ownerFilter,
                  // 'all' 是 UI 哨兵，进 controller 前翻译回 null（= 不筛选）
                  onSelected: (o) => ref
                      .read(lettersListProvider.notifier)
                      .setOwnerFilter(o == 'all' ? null : o),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (state.phase) {
                ListPhase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                ListPhase.empty => const Center(child: Text('没有符合条件的信')),
                ListPhase.error => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('列表加载失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.read(lettersListProvider.notifier).refresh(),
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

class _OwnerFilterButton extends StatelessWidget {
  const _OwnerFilterButton({required this.value, required this.onSelected});

  final String? value;
  final void Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    final label = switch (value) {
      'seed' => '种子信',
      'user' => '有主信',
      _ => '全部来源',
    };
    return PopupMenuButton<String>(
      initialValue: value ?? 'all',
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'all', child: Text('全部来源')),
        PopupMenuItem(value: 'seed', child: Text('种子信')),
        PopupMenuItem(value: 'user', child: Text('有主信')),
      ],
      tooltip: '按来源筛选',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_outlined, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}
