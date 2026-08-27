/// 我的信（F6）—— 我寄出的每一封都在这里（含审核中）。
///
/// 交互纪律：点按 = 读（只有公开的能读）；其余一律弹「长按操作区」
/// ——服务端对非 public 信对读者侧 404，与其让阅读器抛叙事空态，
/// 不如就地解释状态并给出唯一可用动作。下架走两段式确认（同 sheet
/// 内翻面），destructive 只落在确认一段。
///
/// 布局纪律与发掘页一致：默认 KazeScaffold、卡片直排。离开-返回（阅读
/// 器/写信）走静默刷新，列表不闪加载图；操作区的开合不算回焦、不发请求。
/// 列表不移除已下架的信——本页是唯一能
/// 看到自己落点与下场的地方。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/widgets/kaze_scaffold.dart';
import '../../app/widgets/letter_summary_card.dart';
import '../../app/widgets/narrative_card.dart';
import '../../data/models/letter.dart';
import 'my_letters_controller.dart';

class MyLettersScreen extends ConsumerStatefulWidget {
  const MyLettersScreen({super.key});

  @override
  ConsumerState<MyLettersScreen> createState() => _MyLettersScreenState();
}

class _MyLettersScreenState extends ConsumerState<MyLettersScreen>
    with RouteAware {
  /// 操作区（PopupRoute）开合位：showNatsuSheet 压在本页之上，关闭时
  /// RouteAware 的 didPopNext 照样触发——但列表在下架成功时已原地
  /// 更新，失败时原样保留，这次「回焦」不该也不能引来全页重拉。
  bool _inActionSheet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(myLettersControllerProvider.notifier).start();
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
    // 弹层关闭不算回焦；真正的离开-返回（阅读器/写信）走静默刷新，
    // 列表留在原地不闪加载图。
    if (_inActionSheet) return;
    ref.read(myLettersControllerProvider.notifier).refresh();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myLettersControllerProvider);
    final controller = ref.read(myLettersControllerProvider.notifier);

    // 下架成败的一次性提示：notice 是 record，结构相等比较让监听
    // 恰好在每条新提示上触发一次。
    ref.listen(myLettersControllerProvider.select((state) => state.notice), (
      _,
      notice,
    ) {
      if (notice != null) showNatsuToast(context, notice.message);
    });

    return KazeScaffold(
      title: '我的信',
      scrollable: false,
      body: switch (state.phase) {
        MyLettersPhase.loading => const _LoadingBody(),
        MyLettersPhase.empty => NarrativeCard(
          title: '还没有寄出过信',
          subtitle: '写一封交给风，它会替你记住此刻',
          actionLabel: '去写第一封信',
          onAction: () => context.push(Routes.write),
        ),
        MyLettersPhase.error => NarrativeCard(
          title: '没能拿到你的信',
          subtitle: '检查网络后再试一次',
          actionLabel: '再试一次',
          onAction: () => controller.start(),
        ),
        _ => _ListBody(
          items: state.items,
          onOpenItem: _openItem,
          onActions: _openActionSheet,
        ),
      },
    );
  }

  /// 点卡分流：公开 = 去读；非公开 = 服务端必回 404，就地弹操作区解释。
  void _openItem(MyLetterItemView view) {
    if (view.status == LetterStatus.public) {
      context.push(Routes.readerOf(view.id));
      return;
    }
    _openActionSheet(view);
  }

  /// 长按操作区：状态一句话 + （能下架时的）唯一动作。
  Future<void> _openActionSheet(MyLetterItemView view) async {
    _inActionSheet = true;
    try {
      await showNatsuSheet(
        context: context,
        title: const Text('你写的这封信'),
        child: _OwnerActionSheet(
          status: view.status,
          onConfirmTakeDown: () {
            Navigator.of(context).pop();
            ref.read(myLettersControllerProvider.notifier).takeDown(view.id);
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
          Text('正在翻你的信箱', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// ready 态：摘要卡列表（下拉刷新；徽标与时间同行贴右）。
class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.items,
    required this.onOpenItem,
    required this.onActions,
  });

  final List<MyLetterItemView> items;
  final void Function(MyLetterItemView) onOpenItem;
  final void Function(MyLetterItemView) onActions;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      // 下拉刷新 = 静默刷新：列表不闪加载图，进度交给指示器本身
      onRefresh: () => ProviderScope.containerOf(
        context,
        listen: false,
      ).read(myLettersControllerProvider.notifier).refresh(),
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
            statusLabel: view.statusLabel,
            onTap: () => onOpenItem(view),
            onLongPress: () => onActions(view),
          );
        },
      ),
    );
  }
}

/// 长按操作区本体——两段式：状态解释 → 确认。段内自持 busy 位，
/// 双发在按钮禁用层挡住；成功提示由 notice 协议冒泡到页面 toast。
class _OwnerActionSheet extends StatefulWidget {
  const _OwnerActionSheet({
    required this.status,
    required this.onConfirmTakeDown,
  });

  final LetterStatus status;
  final VoidCallback onConfirmTakeDown;

  @override
  State<_OwnerActionSheet> createState() => _OwnerActionSheetState();
}

class _OwnerActionSheetState extends State<_OwnerActionSheet> {
  bool _confirming = false;
  bool _busy = false;

  /// 一句叙事把当前处境说清：操作区的第一行永远是「它在哪」。
  String get _statusSentence => switch (widget.status) {
    LetterStatus.public => '正在漂流与发掘里旅行，等一位陌生人拆开。',
    LetterStatus.pending => '还在审核中，通过后才会出发。',
    LetterStatus.rejected => '没有通过审核，只有你自己看得见它。',
    LetterStatus.takenDown => '已经从漂流与发掘中退场；写下的回信不会受影响。',
  };

  bool get _canTakeDown =>
      widget.status == LetterStatus.public ||
      widget.status == LetterStatus.pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _confirming ? _takeDownFinePrint : _statusSentence,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: KazeColors.inkSoft,
          ),
        ),
        const SizedBox(height: KazeSpacing.md),
        if (!_confirming) _buildStageOne() else _buildStageTwo(),
      ],
    );
  }

  Widget _buildStageOne() {
    if (_canTakeDown) {
      return NatsuButton(
        variant: NatsuButtonVariant.destructive,
        onPressed: () => setState(() => _confirming = true),
        child: const Text('下架这封信'),
      );
    }
    // 无可操作状态的收尾钮：ghost 低强调，弹层本身也可点纸缘关闭。
    return NatsuButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('知道啦'),
    );
  }

  Widget _buildStageTwo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NatsuButton(
          variant: NatsuButtonVariant.destructive,
          onPressed: _busy ? null : widget.onConfirmTakeDown,
          child: Text(_busy ? '正在把它收回……' : '确认下架'),
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
    );
  }

  /// 确认段的语义边界：说清「不是删除」与「不可撤销」两件事。
  static const String _takeDownFinePrint =
      '不是删除——它从漂流与发掘中退场，别人写给它的回信不受影响；'
      '这一步无法撤销。';
}
