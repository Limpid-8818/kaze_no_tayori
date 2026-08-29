/// 信件列表/审核的共享控制器与列表行。
///
/// Review（审核队列）与 Letters（信件管理）共用 [LetterListController]
/// 的四相骨架与筛选口径，只是默认筛选不同：前者 status=pending，
/// 后者全量可调。状态流转动作（通过/驳回/下架/恢复/赦免）也集中在此。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/admin.dart';
import '../../data/models/enums.dart';
import '../../shared/widgets.dart' show StatusBadge;

enum ListPhase { loading, ready, empty, error }

class LetterListState {
  const LetterListState({
    this.phase = ListPhase.loading,
    this.items = const [],
    this.statusFilter,
    this.deliveryModeFilter,
    this.ownerFilter,
    this.notice,
  });

  final ListPhase phase;
  final List<AdminLetterSummary> items;

  /// null = 全部。
  final LetterStatus? statusFilter;
  final DeliveryMode? deliveryModeFilter;
  final String? ownerFilter;

  /// 一次性回执（record + 单调 seq，防 ref.listen 撞车）。
  final ({String message, int seq})? notice;

  LetterListState copyWith({
    ListPhase? phase,
    List<AdminLetterSummary>? items,
    LetterStatus? statusFilter,
    DeliveryMode? deliveryModeFilter,
    String? ownerFilter,
    bool clearFilters = false,
    ({String message, int seq})? notice,
  }) => LetterListState(
    phase: phase ?? this.phase,
    items: items ?? this.items,
    statusFilter: clearFilters ? null : (statusFilter ?? this.statusFilter),
    deliveryModeFilter: clearFilters
        ? null
        : (deliveryModeFilter ?? this.deliveryModeFilter),
    ownerFilter: clearFilters ? null : (ownerFilter ?? this.ownerFilter),
    notice: notice,
  );
}

class LetterListController extends Notifier<LetterListState> {
  /// 默认筛选（review 传 pending，letters 传 null）。
  LetterListController({this.initialStatus, this.initialOwner = 'all'});

  final LetterStatus? initialStatus;
  final String initialOwner;

  int _noticeSeq = 0;

  @override
  LetterListState build() => LetterListState(
    statusFilter: initialStatus,
    ownerFilter: initialOwner == 'all' ? null : initialOwner,
  );

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final page = await ref
          .read(adminApiProvider)
          .letters(
            status: state.statusFilter,
            deliveryMode: state.deliveryModeFilter,
            owner: state.ownerFilter,
          );
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: page.items.isEmpty ? ListPhase.empty : ListPhase.ready,
        items: page.items,
      );
    } on ApiFailure {
      if (!ref.mounted) return;
      state = state.copyWith(phase: ListPhase.error);
    }
  }

  Future<void> setStatusFilter(LetterStatus? status) async {
    // 筛选切换用显式构造：copyWith 的 `?? this` 会把 null 当「不改」吞掉，
    // 导致「全部状态」取消不了
    state = LetterListState(
      phase: state.phase,
      items: state.items,
      statusFilter: status,
      deliveryModeFilter: state.deliveryModeFilter,
      ownerFilter: state.ownerFilter,
    );
    await refresh();
  }

  Future<void> setDeliveryModeFilter(DeliveryMode? mode) async {
    state = LetterListState(
      phase: state.phase,
      items: state.items,
      statusFilter: state.statusFilter,
      deliveryModeFilter: mode,
      ownerFilter: state.ownerFilter,
    );
    await refresh();
  }

  Future<void> setOwnerFilter(String? owner) async {
    state = LetterListState(
      phase: state.phase,
      items: state.items,
      statusFilter: state.statusFilter,
      deliveryModeFilter: state.deliveryModeFilter,
      ownerFilter: owner,
    );
    await refresh();
  }

  void _notify(String message) {
    _noticeSeq += 1;
    state = state.copyWith(notice: (message: message, seq: _noticeSeq));
  }

  /// 审核裁决：pending → public / rejected（两段确认在 UI 层）。
  Future<void> decide(String id, LetterStatus to) async {
    await _transition(
      id,
      to,
      successMessage: to == LetterStatus.public ? '已通过，信件公开' : '已驳回',
    );
  }

  /// 下架 / 恢复 / 赦免。
  Future<void> transition(String id, LetterStatus to) async {
    final message = switch (to) {
      LetterStatus.takenDown => '已下架，读者侧即刻 404',
      LetterStatus.public => '已恢复公开',
      _ => '状态已更新',
    };
    await _transition(id, to, successMessage: message);
  }

  Future<void> _transition(
    String id,
    LetterStatus to, {
    required String successMessage,
  }) async {
    try {
      await ref.read(adminApiProvider).transitionLetter(id, to);
      if (!ref.mounted) return;
      _notify(successMessage);
      await refresh();
    } on ApiFailure catch (e) {
      if (!ref.mounted) return;
      _notify(e.message);
    }
  }
}

/// 列表行：预览 + 状态徽标 + 落点 + 时间。
class LetterSummaryRow extends StatelessWidget {
  const LetterSummaryRow({super.key, required this.item, this.onTap});

  final AdminLetterSummary item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          item.preview ?? '（纯照片信）',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_modeLabel(item.deliveryMode)} · ${item.placeLabel ?? '无落点'} · '
          '${item.createdAt.month}月${item.createdAt.day}日',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '读${item.counts.read} · 鸣${item.counts.resonance} · 回${item.counts.reply}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(width: 12),
            StatusBadge(status: item.status),
          ],
        ),
      ),
    );
  }
}

String _modeLabel(DeliveryMode mode) => mode == DeliveryMode.stay ? '留' : '投';

/// 审核队列（默认 pending）与信件管理（全量）共用本控制器，只差默认筛选。
class ReviewListController extends LetterListController {
  ReviewListController() : super(initialStatus: LetterStatus.pending);
}

final reviewListProvider =
    NotifierProvider<ReviewListController, LetterListState>(
      ReviewListController.new,
    );

class LettersListController extends LetterListController {}

final lettersListProvider =
    NotifierProvider<LettersListController, LetterListState>(
      LettersListController.new,
    );
