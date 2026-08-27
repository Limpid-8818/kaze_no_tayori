/// 随机漂流页 —— 从陌生人的思绪里抽一封。
///
/// 三幕：未抽（副标题 + 「抽一封信」）→ 抽到（桌面上的封筒 +
/// 开信/换一封）→ 池空叙事态。画布裁剪：中央信封图案与
/// 「纯随机 · 不做加权」hint 不实现（用户指示，见 KazeDriftDims 注）。
/// 控制逻辑全在 [DriftController]，本文件只做布局与交互挂接。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/widgets/kaze_scaffold.dart';
import '../../app/widgets/narrative_card.dart';
import 'drift_controller.dart';
import 'drift_view.dart';
import 'widgets/drift_action_bar.dart';

class DriftScreen extends ConsumerStatefulWidget {
  const DriftScreen({super.key});

  @override
  ConsumerState<DriftScreen> createState() => _DriftScreenState();
}

class _DriftScreenState extends ConsumerState<DriftScreen> {
  @override
  void initState() {
    super.initState();
    // 重进即重置：读过的信不留桌面，未拆的也不替用户保管（见
    // DriftController.reset）。用户裁决：读完返回应看到干净的起点。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(driftControllerProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driftControllerProvider);
    final controller = ref.read(driftControllerProvider.notifier);

    // 控制器不持有 context：一次性提示经 notice 转发到这里弹 toast
    ref.listen(driftControllerProvider, (previous, next) {
      final notice = next.notice;
      if (notice != null && notice.seq != previous?.notice?.seq) {
        showNatsuToast(context, notice.message);
      }
    });

    return KazeScaffold(
      title: '随机漂流',
      scrollable: false,
      body: switch (state.phase) {
        DriftPhase.empty => NarrativeCard(
          title: '此刻还没有漂来的信',
          subtitle: '风把它们送去了别处，晚点再来',
          actionLabel: '再试试',
          onAction: () => controller.draw(),
        ),
        DriftPhase.error => NarrativeCard(
          title: '没能抽到信',
          subtitle: '网络不太顺，稍后再试',
          actionLabel: '再试一次',
          onAction: () => controller.draw(),
        ),
        _ when state.view == null => _DrawIntro(
          busy: state.phase == DriftPhase.drawing,
          onDraw: controller.draw,
        ),
        _ => _Desk(
          view: state.view!,
          busy: state.swapping,
          onOpen: () => _open(context, state.view!.id),
        ),
      },
      bottom: state.view == null
          ? null
          : DriftActionBar(
              busy: state.swapping,
              onOpen: () => _open(context, state.view!.id),
              onSwap: () => controller.draw(),
            ),
    );
  }

  /// 拆封是一次性仪式：replace 进阅读器（进入即 markRead 恰一次），
  /// 返回不再见已拆的封筒。
  void _open(BuildContext context, String letterId) =>
      context.pushReplacement(Routes.readerOf(letterId));
}

/// 第一幕：居中副标题 + 主行动。手写体大字沿 about_screen 先例直取令牌。
class _DrawIntro extends StatelessWidget {
  const _DrawIntro({required this.busy, required this.onDraw});

  final bool busy;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    // 画布副标题为手写体 22/36；warmBody(hwBody 20) 最近档放大至此（偏差记录）
    final subtitleStyle = KazeLetterType.warmBody.copyWith(
      fontSize: 22,
      height: 36 / 22,
    );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '从陌生人的思绪里，\n随机抽一封。',
            style: subtitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KazeSpacing.xl),
          if (busy)
            const NatsuSpinner()
          else
            NatsuButton(
              variant: NatsuButtonVariant.primary,
              onPressed: onDraw,
              child: const Text('抽一封信'),
            ),
        ],
      ),
    );
  }
}

/// 第二幕：桌面上的封筒；换一封时旧封筒留在原地，spinner 盖章式浮现。
class _Desk extends StatelessWidget {
  const _Desk({required this.view, required this.busy, required this.onOpen});

  final DriftEnvelopeView view;
  final bool busy;
  final VoidCallback onOpen;

  /// 小屏兜底：竖形封筒很高（1:2.2），可用高度不足时按高度收敛宽度。
  double _widthFor(double maxHeight) {
    var width = KazeDriftDims.envelopeW;
    final allowedHeight = maxHeight - KazeSpacing.lg * 2 - NatsuSpacing.xl;
    if (width * Envelope.aspectRatio > allowedHeight) {
      width = math.max(140, allowedHeight / Envelope.aspectRatio);
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final envelope = Envelope(
          seedId: view.seedId,
          skin: view.skin,
          addressee: view.addressee,
          place: view.place,
          date: view.date,
          weather: view.weather,
          width: _widthFor(constraints.maxHeight),
        );
        return Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(KazeSpacing.lg),
                child: envelope,
              ),
            ),
            if (busy)
              const Positioned.fill(child: Center(child: NatsuSpinner())),
          ],
        );
      },
    );
  }
}
