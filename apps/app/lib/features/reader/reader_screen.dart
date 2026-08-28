/// 读信页 —— 地点·时间·天气 + 图文流 + 共鸣/回信/举报，并可切到这封
/// 信抵达时的封筒封面（正放预览，工具行原地切换）；「⋯」里可把这封
/// 信导出成匿名长图。
///
/// **不渲染任何作者信息**（服务端也不会给）。短诗、音乐引用本阶段
/// 不展示（mapper 丢弃）。控制逻辑全在 [ReaderController]，本文件只做
/// 布局与交互挂接。
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/widgets/kaze_paper_stack.dart';
import '../../app/widgets/kaze_pill_action.dart';
import '../../app/widgets/kaze_scaffold.dart';
import '../../app/widgets/kaze_view_toggle.dart';
import 'letter_exporter.dart';
import 'letter_view.dart';
import 'reader_controller.dart';
import 'widgets/letter_export_sheet.dart';
import 'widgets/reader_action_bar.dart';
import 'widgets/reader_empty_state.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.letterId, super.key});

  final String letterId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  /// 封筒封面态。纯视图开关，不进 ReaderState——共鸣/记抄本等动作
  /// 与视图无关；工具行是封筒态唯一的返回路径。
  bool _showEnvelope = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(readerControllerProvider(widget.letterId).notifier).start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // family 按 letterId 分实例：被叠栈的原信页不随上层页面的加载而变
    final state = ref.watch(readerControllerProvider(widget.letterId));
    final controller = ref.read(
      readerControllerProvider(widget.letterId).notifier,
    );
    final view = state.view;

    // 控制器不持有 context：一次性提示经 notice 转发到这里弹 toast
    ref.listen(readerControllerProvider(widget.letterId), (previous, next) {
      final notice = next.notice;
      if (notice != null && notice.seq != previous?.notice?.seq) {
        showNatsuToast(context, notice.message);
      }
    });

    return KazeScaffold(
      title: '读一封信',
      backgroundGradient: skyOfLetter(view),
      // 导出 / 记入抄本 / 举报在 AppBar「⋯」菜单；仅 ready 态可用
      // （「看原信」已上提到工具行，与「看封筒」同排）
      actions: state.phase == ReaderPhase.ready ? [_moreMenu()] : null,
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
        ReaderPhase.ready => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 信纸上方的工具行：切换钮靠左，「看原信」居右，两种视图下常驻
            Padding(
              padding: const EdgeInsets.only(bottom: KazeSpacing.sm),
              child: Row(
                children: [
                  KazeViewToggle(
                    envelopeShown: _showEnvelope,
                    onToggle: () =>
                        setState(() => _showEnvelope = !_showEnvelope),
                  ),
                  const Spacer(),
                  // 回信溯源：这封信是对另一封的回应，递出去看那封原信。
                  // 原信 404 由新页面的空态兜住。
                  if (view?.parentLetterId != null)
                    KazePillAction(
                      icon: Icons.history_edu,
                      label: '看原信',
                      onTap: () =>
                          context.push(Routes.readerOf(view!.parentLetterId!)),
                    ),
                ],
              ),
            ),
            // 顶锚换纸（默认 topCenter）：信纸/封筒顶边都钉在工具行
            // 正下方，高度差在下方平滑收放，信纸全程不挪位
            KazePaperStack(
              child: _showEnvelope ? _envelopeView(view!) : _letterView(view!),
            ),
          ],
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

  /// 信纸态：拆封后的阅读流（原有形态原样搬入切换台）。
  Widget _letterView(LetterView view) {
    return Center(
      key: const ValueKey('paper'),
      child: LetterReading(
        blocks: view.blocks,
        photoResolver: cachedPhotoResolver,
        seedId: view.id,
        place: view.place,
        time: view.timeLabel,
        weather: view.weatherText,
        signature: view.signature,
      ),
    );
  }

  /// 封筒态：这封信抵达时的封面（正放）。宛名/皮肤/邮戳三要素来自
  /// mapper 扩展位；地点缺省退化与漂流页同口径。
  Widget _envelopeView(LetterView view) {
    return Center(
      key: const ValueKey('envelope'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: KazeSpacing.lg),
        child: Envelope(
          seedId: view.id,
          skin: view.skin,
          addressee: view.addressee,
          place: view.place ?? '风寄出的地方',
          date: view.timeLabel,
          weather: view.weatherText,
          tilt: 0,
          width: KazeDriftDims.envelopeW,
        ),
      ),
    );
  }

  /// AppBar「⋯」：导出图片 / 记入抄本 / 举报。「看原信」在工具行居右。
  Widget _moreMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      tooltip: '更多',
      // M3 默认 menuPadding 在菜单上下各留 8px，首末项按下的 ink 涟漪
      // 到不了菜单边缘、露出一圈空隙；归零让涟漪贴边。
      menuPadding: EdgeInsets.zero,
      onSelected: (value) {
        switch (value) {
          case 'export':
            _exportImage();
          case 'scripbook':
            ref
                .read(readerControllerProvider(widget.letterId).notifier)
                .saveToScripbook();
          case 'report':
            _openReportSheet();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'export', child: Text('导出图片')),
        const PopupMenuItem(value: 'scripbook', child: Text('记入抄本')),
        const PopupMenuItem(value: 'report', child: Text('举报')),
      ],
    );
  }

  /// 导出长图：离屏渲染（照片先全部进缓存）→ 预览 sheet 选保存/分享。
  /// 生成中用不可关闭的弹层挡住重复触发；照片没下完整体不导（宁可不
  /// 导也不出灰块图）。
  Future<void> _exportImage() async {
    final view = ref.read(readerControllerProvider(widget.letterId)).view;
    if (view == null) return;

    unawaited(
      showNatsuDialog(
        context: context,
        barrierDismissible: false,
        title: const Text('正在装图'),
        body: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NatsuSpinner(),
            SizedBox(width: NatsuSpacing.sm),
            Text('把这封信渲染成长图…'),
          ],
        ),
      ),
    );
    try {
      final png = await exportLetterImage(context, view);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 收起 loading
      await showLetterExportSheet(context, png: png);
    } on LetterPhotoNotReadyException {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showNatsuToast(context, '信里的照片还没下载完，联网后再试试');
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showNatsuToast(context, '导出失败了，稍后再试试');
    }
  }

  /// 举报弹层：预设理由一个 tap 完事，不做自由输入框。
  Future<void> _openReportSheet() async {
    await showNatsuSheet(
      context: context,
      title: const Text('举报这封信'),
      child: _ReportSheet(
        onPick: (reason) {
          Navigator.of(context).pop();
          ref
              .read(readerControllerProvider(widget.letterId).notifier)
              .report(reason: reason);
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
