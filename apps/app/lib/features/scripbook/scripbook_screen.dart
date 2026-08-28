/// 抄本（F7）—— 我收藏的信。
///
/// 布局与交互纪律沿「我的信」（F6）：默认 KazeScaffold、卡片直排、
/// RouteAware 离开-返回静默刷新，操作区的开合不算回焦。点卡 = 去读
/// （原信若已被下架，由阅读器的叙事空态兜底）；长按弹「移出操作区」，
/// 两段式确认——被收藏读过的信不会再漂流回来，移出事实上找不回，
/// 与下架同级对待。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/widgets/kaze_refresh_indicator.dart';
import '../../app/widgets/kaze_scaffold.dart';
import '../../app/widgets/letter_summary_card.dart';
import '../../app/widgets/narrative_card.dart';
import 'scripbook_controller.dart';

class ScripbookScreen extends ConsumerStatefulWidget {
  const ScripbookScreen({super.key});

  @override
  ConsumerState<ScripbookScreen> createState() => _ScripbookScreenState();
}

class _ScripbookScreenState extends ConsumerState<ScripbookScreen>
    with RouteAware {
  /// 操作区（PopupRoute）开合位：sheet 关闭触发的 didPopNext 不是
  /// 回焦——移出成败已由控制器就地更新列表/发提示，不能引来重拉。
  bool _inActionSheet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(scripbookControllerProvider.notifier).start();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // 弹层关闭不算回焦；从阅读器回来走静默刷新（可能在那边刚收进了信）。
    if (_inActionSheet) return;
    ref.read(scripbookControllerProvider.notifier).refresh();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scripbookControllerProvider);
    final controller = ref.read(scripbookControllerProvider.notifier);

    // 移出成败的一次性提示：record 结构相等让监听恰好在每条新提示上
    // 触发一次。
    ref.listen(scripbookControllerProvider.select((state) => state.notice), (
      _,
      notice,
    ) {
      if (notice != null) showNatsuToast(context, notice.message);
    });

    return KazeScaffold(
      title: '抄本',
      scrollable: false,
      body: switch (state.phase) {
        ScripbookPhase.loading => const _LoadingBody(),
        ScripbookPhase.empty => NarrativeCard(
          title: '还没有收进一封信',
          subtitle: '读到想留住的话，在读信页右上角 ⋯ 把它记进来',
          actionLabel: '去发掘一封信',
          onAction: () => context.push(Routes.discover),
        ),
        ScripbookPhase.error => NarrativeCard(
          title: '没能翻开你的抄本',
          subtitle: '检查网络后再试一次',
          actionLabel: '再试一次',
          onAction: () => controller.start(),
        ),
        _ => _ListBody(
          items: state.items,
          onOpenItem: _openItem,
          onRemove: _openActionSheet,
        ),
      },
    );
  }

  void _openItem(ScripbookItemView view) {
    context.push(Routes.readerOf(view.id));
  }

  /// 长按操作区：两段式（解释 → 确认），语义同下架——移出后这封信
  /// 不会再漂流回来。成功提示由 notice 协议冒泡到页面 toast。
  Future<void> _openActionSheet(ScripbookItemView view) async {
    _inActionSheet = true;
    try {
      await showNatsuSheet(
        context: context,
        title: const Text('你收藏的这封信'),
        child: _RemoveSheet(
          onConfirmRemove: () {
            Navigator.of(context).pop();
            ref.read(scripbookControllerProvider.notifier).remove(view.id);
          },
        ),
      );
    } finally {
      _inActionSheet = false;
    }
  }
}

// ---------------------------------------------------------------------

/// 加载中的过渡态。
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NatsuSpinner(),
          const SizedBox(height: KazeSpacing.sm),
          Text('正在翻开你的抄本', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// ready 态：摘要卡列表（下拉刷新；无状态徽标，同发掘列表口径）。
class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.items,
    required this.onOpenItem,
    required this.onRemove,
  });

  final List<ScripbookItemView> items;
  final void Function(ScripbookItemView) onOpenItem;
  final void Function(ScripbookItemView) onRemove;

  @override
  Widget build(BuildContext context) {
    return KazeRefreshIndicator(
      // 下拉刷新 = 静默刷新：列表不闪加载图，进度交给指示器本身
      onRefresh: () => ProviderScope.containerOf(
        context,
        listen: false,
      ).read(scripbookControllerProvider.notifier).refresh(),
      child: ListView.separated(
        // 下拉刷新需要列表可越界拖动
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: KazeSpacing.sm),
        itemBuilder: (context, index) {
          final view = items[index];
          return LetterSummaryCard(
            timeLabel: view.timeLabel,
            poem: view.poemLines.join('\n'),
            previewText: view.previewText,
            placeLabel: view.placeLabel,
            onTap: () => onOpenItem(view),
            onLongPress: () => onRemove(view),
          );
        },
      ),
    );
  }
}

/// 移出操作区本体——两段式：说明 → 确认。段内自持 busy 位，双发在
/// 按钮禁用层挡住；确认即 pop（列表更新交给控制器）。
class _RemoveSheet extends StatefulWidget {
  const _RemoveSheet({required this.onConfirmRemove});

  final VoidCallback onConfirmRemove;

  @override
  State<_RemoveSheet> createState() => _RemoveSheetState();
}

class _RemoveSheetState extends State<_RemoveSheet> {
  bool _confirming = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _confirming ? _removeFinePrint : _explanation,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: KazeColors.inkSoft,
          ),
        ),
        const SizedBox(height: KazeSpacing.md),
        if (!_confirming)
          NatsuButton(
            variant: NatsuButtonVariant.destructive,
            onPressed: () => setState(() => _confirming = true),
            child: const Text('移出抄本'),
          )
        else ...[
          NatsuButton(
            variant: NatsuButtonVariant.destructive,
            onPressed: _busy ? null : widget.onConfirmRemove,
            child: Text(_busy ? '正在把它放归风里……' : '确认移出'),
          ),
          const SizedBox(height: KazeSpacing.sm),
          NatsuButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _busy = false;
                    _confirming = false;
                  }),
            child: const Text('再想想'),
          ),
        ],
      ],
    );
  }

  /// 第一段把处境讲清：抄本是私人的，但移出的代价是「不再相遇」。
  static const String _explanation = '它会从你的抄本里退场；读过的信不会再漂流回来，之后很难再遇见它。';

  /// 确认段的语义边界：说清「不是删除原信」与「不可找回」两件事。
  static const String _removeFinePrint =
      '不是删除——信还在世上，写给它的回信也不受影响；'
      '只是你的抄本里从此没有它，这一步无法撤销。';
}
