/// 状态徽标与两段式确认弹层。
library;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/models/enums.dart';

/// 状态徽标：色点 + 中文标签（待审核/公开/已驳回/已下架）。
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final LetterStatus status;

  @override
  Widget build(BuildContext context) {
    final color = AdminTheme.statusColor(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(AdminTheme.statusLabel(status)),
      ],
    );
  }
}

/// 两段式确认弹层：返回 true = 确认执行。
///
/// [destructive] 为 true 时确认按钮用错误色（驳回/下架等不可逆感操作）。
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确认',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 轻提示（操作结果回执）。
void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        width: 420,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// 「全部」哨兵（必须非 null，见 StatusFilterButton 注释）。
const String filterAll = 'all';

/// 状态中文标签（徽标与筛选共用）。
String statusName(LetterStatus status) => switch (status) {
  LetterStatus.pending => '待审核',
  LetterStatus.public => '公开',
  LetterStatus.rejected => '已驳回',
  LetterStatus.takenDown => '已下架',
};

/// 状态筛选下拉（审核队列与信件管理共用）。
class StatusFilterButton extends StatelessWidget {
  const StatusFilterButton({
    super.key,
    required this.value,
    required this.onSelected,
  });

  final LetterStatus? value;
  final void Function(LetterStatus?) onSelected;

  @override
  Widget build(BuildContext context) {
    // PopupMenuButton 把「选中 value 为 null 的项」与「点外部取消」走同一
    // onCanceled 路径，null 哨兵永远选不中——用非空 'all' 哨兵表示全部
    return PopupMenuButton<Object>(
      initialValue: value ?? filterAll,
      onSelected: (selected) =>
          onSelected(selected == filterAll ? null : selected as LetterStatus),
      itemBuilder: (context) => const [
        PopupMenuItem(value: filterAll, child: Text('全部状态')),
        PopupMenuItem(value: LetterStatus.pending, child: Text('待审核')),
        PopupMenuItem(value: LetterStatus.public, child: Text('公开')),
        PopupMenuItem(value: LetterStatus.rejected, child: Text('已驳回')),
        PopupMenuItem(value: LetterStatus.takenDown, child: Text('已下架')),
      ],
      tooltip: '按状态筛选',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 18),
            const SizedBox(width: 6),
            Text(value == null ? '全部状态' : statusName(value!)),
          ],
        ),
      ),
    );
  }
}
