/// 回信告知页（PRD 6.5）——「你于某地写的那封信，收到一封回信 ✦」。
///
/// 只是获知，不是私信：条目不显示回信作者，点击直达公开回信本体
/// （下架/404 由阅读器空态兜住）。控制逻辑全在 [NotificationsController]。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/widgets/kaze_scaffold.dart';
import '../../app/widgets/narrative_card.dart';
import 'notifications_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationsControllerProvider.notifier).start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return KazeScaffold(
      title: '回信告知',
      scrollable: false,
      body: switch (state.phase) {
        NotificationsPhase.loading => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NatsuSpinner(),
              const SizedBox(height: NatsuSpacing.sm),
              Text('正在翻看风的来信', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        // v1 还没有通知记录的空态与拉取失败分开叙事
        NotificationsPhase.ready when state.items.isEmpty => NarrativeCard(
          title: '暂时没有回音',
          subtitle: '你写下的信还在风的路上；有回信时会在这里告诉你',
          actionLabel: '刷新',
          onAction: () => controller.start(),
        ),
        NotificationsPhase.error => NarrativeCard(
          title: '没能拿到回信告知',
          subtitle: '检查网络后再试一次',
          actionLabel: '再试一次',
          onAction: () => controller.start(),
        ),
        NotificationsPhase.ready => _NoticeList(items: state.items),
      },
    );
  }
}

/// ready 态条目列表。未读加重 + 珊瑚圆点；已读整行淡化但不消失——
/// 告知是收信史的一部分，可随时回访那封回信。
///
/// 顶部对齐（Align topCenter）：KazeScaffold 的内容层默认居中，
/// 条目少时列表会浮在屏幕中部——信应从页首开始读。
class _NoticeList extends ConsumerWidget {
  const _NoticeList({required this.items});

  final List<NotificationItemView> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: KazeSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items) ...[
              _NoticeTile(item: item),
              const SizedBox(height: KazeSpacing.sm),
            ],
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: KazeSpacing.sm),
                child: Text(
                  '只有这些了。风会继续送来回信的消息。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: KazeColors.inkFaint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticeTile extends ConsumerWidget {
  const _NoticeTile({required this.item});

  final NotificationItemView item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final messageStyle = item.isRead
        ? theme.textTheme.bodyMedium?.copyWith(color: KazeColors.inkFaint)
        : theme.textTheme.bodyLarge;

    return Card(
      color: NatsuColors.envelope,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => _open(context, ref),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KazeRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KazeSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 未读珊瑚圆点；已读也让位，条目文字左缘保持对齐
              Padding(
                padding: const EdgeInsets.only(top: KazeSpacing.xs),
                child: Container(
                  width: KazeHomeDims.noticeDot,
                  height: KazeHomeDims.noticeDot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isRead
                        ? Colors.transparent
                        : theme.colorScheme.tertiary,
                  ),
                ),
              ),
              const SizedBox(width: KazeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.message, style: messageStyle),
                    const SizedBox(height: KazeSpacing.xs),
                    Text(
                      item.timeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: KazeColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 先标已读（成功则角标联动减一），随后无论成败都去读信本体；
  /// 失败时条目保持未读高亮，返回后一眼能看出来没送达。
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await ref.read(notificationsControllerProvider.notifier).markRead(item.id);
    if (!context.mounted) return;
    context.push(Routes.readerOf(item.letterId));
  }
}
