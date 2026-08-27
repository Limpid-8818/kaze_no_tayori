/// 应用级未读数（F5）——抽屉「回信告知」角标的**唯一所有者**。
///
/// 状态只有一个数字。拉取时机全部外部驱动：开页与回前台由 AppLifecycle
/// 调 [refresh]（`unread_only=true`，上限 50——v1 契约无 total 字段，
/// 条数即计数，next_cursor 恒 null）；notifications 页标记一条已读成功后
/// 调 [decrement]，单向同步、不做双向 watch。
///
/// 失败静默保留旧值：角标是可降级模块，网络不好时不打扰收信人。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../data/api/providers.dart';

/// 契约允许的 unread 查询上限（limit ≤ 50）。
const _unreadQueryLimit = 50;

final unreadCountControllerProvider =
    NotifierProvider<UnreadCountController, int>(UnreadCountController.new);

class UnreadCountController extends Notifier<int> {
  @override
  int build() => 0;

  /// 全量重拉未读数（开页 / 回前台）。
  Future<void> refresh() async {
    try {
      final page = await ref
          .read(meApiProvider)
          .notifications(unreadOnly: true, limit: _unreadQueryLimit);
      state = page.items.length;
    } on ApiFailure {
      // 故意忽略：保持上次计数
    }
  }

  /// notifications 标记一条已读成功后的单向同步；不为负。
  void decrement() {
    if (state > 0) state = state - 1;
  }
}
