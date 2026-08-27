/// 读信页 —— 地点·时间·天气 + 图文流 + 共鸣/回信/举报。
///
/// **不渲染任何作者信息**（服务端也不会给）。短诗、音乐引用、皮肤本阶段
/// 不展示（mapper 丢弃）。控制逻辑全在 [ReaderController]，本文件只做
/// 布局与交互挂接。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/widgets/kaze_scaffold.dart';
import 'letter_view.dart';
import 'reader_controller.dart';
import 'widgets/reader_action_bar.dart';
import 'widgets/reader_empty_state.dart';

/// 读信页天空以信为准 —— 信携带的天气 × 信落笔时刻的时段查表
/// （「环境光随信」）；没带天气或还没读进来 → 默认昼·晴。
/// 显式传给 [KazeScaffold] 后不吃全局天色联动。
Gradient _skyFor(LetterView? view) {
  if (view == null || view.weatherIcon == null) {
    return KazeSky.defaultGradient;
  }
  return KazeSky.of(
    KazeSky.fromIcon(view.weatherIcon),
    KazeSky.daypartOf(view.createdAt),
  );
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.letterId, super.key});

  final String letterId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(readerControllerProvider.notifier).start(widget.letterId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerControllerProvider);
    final controller = ref.read(readerControllerProvider.notifier);
    final view = state.view;

    // 控制器不持有 context：一次性提示经 notice 转发到这里弹 toast
    ref.listen(readerControllerProvider, (previous, next) {
      final notice = next.notice;
      if (notice != null && notice.seq != previous?.notice?.seq) {
        showNatsuToast(context, notice.message);
      }
    });

    return KazeScaffold(
      title: '读一封信',
      backgroundGradient: _skyFor(view),
      // 记入抄本 / 查看原信 / 举报在 AppBar「⋯」菜单；仅 ready 态可用
      actions: state.phase == ReaderPhase.ready ? [_moreMenu(view)] : null,
      // ready 内容随信纸长度滚动；空态/错误态不滚动，垂直居中
      scrollable: state.phase == ReaderPhase.ready,
      body: switch (state.phase) {
        ReaderPhase.loading => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NatsuSpinner(),
              SizedBox(height: NatsuSpacing.sm),
              Text('正在打开这封信'),
            ],
          ),
        ),
        ReaderPhase.notFound => const ReaderEmptyState(
          title: '这封信不在了',
          subtitle: '可能已被删除或下架',
        ),
        ReaderPhase.error => ReaderEmptyState(
          title: '没能加载这封信',
          subtitle: '检查网络后再试一次',
          actionLabel: '再试一次',
          onAction: () => controller.retry(),
        ),
        ReaderPhase.ready => Center(
          child: LetterReading(
            blocks: view!.blocks,
            photoResolver: cachedPhotoResolver,
            seedId: view.id,
            place: view.place,
            time: view.timeLabel,
            weather: view.weatherText,
            signature: view.signature,
          ),
        ),
      },
      bottom: state.phase == ReaderPhase.ready
          ? ReaderActionBar(
              resonated: state.resonated,
              resonanceCount: state.resonanceCount,
              onResonate: () => controller.resonate(),
              onReply: () => context.push('${Routes.write}?parent=${view!.id}'),
            )
          : null,
    );
  }

  /// AppBar「⋯」：记入抄本 / 查看它回应的那封信（仅 parent 非空）/
  /// 举报。原信 404 由新页面的空态兜住。
  Widget _moreMenu(LetterView? view) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      tooltip: '更多',
      onSelected: (value) {
        switch (value) {
          case 'scripbook':
            ref.read(readerControllerProvider.notifier).saveToScripbook();
          case 'parent':
            context.push(Routes.readerOf(view!.parentLetterId!));
          case 'report':
            _openReportSheet();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'scripbook', child: Text('记入抄本')),
        if (view?.parentLetterId != null)
          const PopupMenuItem(value: 'parent', child: Text('查看它回应的那封信')),
        const PopupMenuItem(value: 'report', child: Text('举报')),
      ],
    );
  }

  /// 举报弹层：预设理由一个 tap 完事，不做自由输入框。
  Future<void> _openReportSheet() async {
    await showNatsuSheet(
      context: context,
      title: const Text('举报这封信'),
      child: _ReportSheet(
        onPick: (reason) {
          Navigator.of(context).pop();
          ref.read(readerControllerProvider.notifier).report(reason: reason);
        },
      ),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.onPick});

  final ValueChanged<String> onPick;

  static const _reasons = ['垃圾广告', '不当内容', '引起不适', '其他'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reason in _reasons) ...[
          NatsuButton(
            variant: NatsuButtonVariant.secondary,
            onPressed: () => onPick(reason),
            child: Text(reason),
          ),
          const SizedBox(height: NatsuSpacing.sm),
        ],
      ],
    );
  }
}
