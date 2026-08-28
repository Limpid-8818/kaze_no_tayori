/// 回信页控制器（F5）——列表加载、标记已读、与未读数单向同步。
///
/// 告知只是「获知」：原作者不是回信的收件人，点击跳的是公开回信本身
/// （阅读器空态兜住下架/404）。本类持有唯一可变状态 [NotificationsState]，
/// 页面只做布局与交互挂接——MVC 分工与 ReaderController 一致。
///
/// 与 app 级 [unreadCountControllerProvider] 的同步是**单向的**：这里
/// 标记一条已读成功后调它的 decrement()，不做双向 watch。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controllers/unread_count_controller.dart';
import '../../core/relative_time.dart';
import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/notification.dart';

enum NotificationsPhase { loading, ready, error }

/// 一条告知的视图模型。映射集中在此（与 LetterView 同纪律）。
class NotificationItemView {
  const NotificationItemView({
    required this.id,
    required this.letterId,
    required this.message,
    required this.timeLabel,
    required this.isRead,
  });

  final String id;

  /// 要读的那封公开回信本体。
  final String letterId;

  /// PRD 6.5 的叙事句：「你于 {写信日} 在 {地点} 写的那封信，收到一封回信」。
  final String message;
  final String timeLabel;
  final bool isRead;

  static NotificationItemView from(NotificationPublic n) {
    final where = n.parentPlaceLabel ?? '某地';
    final when = n.parentLetterDate;
    // 无日期（旧响应）时回退为不带日期的原句，避免双空格。
    final subject = when == null
        ? '你于 $where'
        : '你于 ${dayLabel(when)} 在 $where';
    return NotificationItemView(
      id: n.id,
      letterId: n.letterId,
      message: '$subject 写的那封信，收到一封回信',
      timeLabel: relativeTimeLabel(n.createdAt),
      isRead: n.isRead,
    );
  }
}

class NotificationsState {
  const NotificationsState({
    this.phase = NotificationsPhase.loading,
    this.items = const [],
  });

  final NotificationsPhase phase;
  final List<NotificationItemView> items;

  NotificationsState copyWith({
    NotificationsPhase? phase,
    List<NotificationItemView>? items,
  }) {
    return NotificationsState(
      phase: phase ?? this.phase,
      items: items ?? this.items,
    );
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() => const NotificationsState();

  /// 进入页面时调用（可重复调用 = 重试）。拉全量历史含已读。
  Future<void> start() async {
    state = const NotificationsState();
    try {
      final page = await ref.read(meApiProvider).notifications(limit: 50);
      state = state.copyWith(
        phase: NotificationsPhase.ready,
        items: [for (final n in page.items) NotificationItemView.from(n)],
      );
    } on ApiFailure {
      state = state.copyWith(phase: NotificationsPhase.error);
    }
  }

  /// 打开一条告知前先标已读：成功则本地翻转并联动未读角标；
  /// 失败静默——条目保持未读高亮就是最直接的「没成功」，
  /// 下次开页还有机会，不打断去读信的路。
  Future<void> markRead(String notificationId) async {
    NotificationItemView? target;
    for (final item in state.items) {
      if (item.id == notificationId) target = item;
    }
    // 已读过的不重发也不扣减；服务端本就幂等，这里省一次往返。
    if (target == null || target.isRead) return;
    try {
      await ref.read(meApiProvider).markNotificationRead(notificationId);
    } on ApiFailure {
      return;
    }
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == notificationId)
            NotificationItemView(
              id: item.id,
              letterId: item.letterId,
              message: item.message,
              timeLabel: item.timeLabel,
              isRead: true,
            )
          else
            item,
      ],
    );
    ref.read(unreadCountControllerProvider.notifier).decrement();
  }
}
