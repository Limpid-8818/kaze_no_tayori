/// 随机漂流页控制器 —— 抽信状态机。
///
/// ARCHITECTURE §5.5 预定：抽信/封筒状态归 DriftController，仅 feature 内。
/// 「换一封」就是再抽一次——排除逻辑在服务端（已开的永不再来，
/// 送达未开的有冷却期）；池抽干时后端回 driftPoolEmpty，这里转成
/// 叙事态而不是错误。开信是纯导航：markRead 恰一次由阅读器负责
/// （ReaderController 进入即幂等上报），本类不碰已读语义。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../data/api/providers.dart';
import 'drift_view.dart';

enum DriftPhase { idle, drawing, drawn, empty, error }

class DriftState {
  const DriftState({this.phase = DriftPhase.idle, this.view, this.notice});

  final DriftPhase phase;

  /// drawn 态才有；其余态为 null（copyWith 用 _unset 哨兵才能清空）。
  final DriftEnvelopeView? view;

  /// 一次性提示（视图层 ref.listen 后弹 NatsuToast）。seq 单调递增。
  final ({String message, int seq})? notice;

  bool get swapping => phase == DriftPhase.drawing && view != null;

  DriftState copyWith({
    DriftPhase? phase,
    Object? view = _unset,
    Object? notice = _unset,
  }) {
    return DriftState(
      phase: phase ?? this.phase,
      view: view == _unset ? this.view : view as DriftEnvelopeView?,
      notice: notice == _unset
          ? this.notice
          : notice as ({String message, int seq})?,
    );
  }

  static const _unset = Object();
}

final driftControllerProvider = NotifierProvider<DriftController, DriftState>(
  DriftController.new,
);

class DriftController extends Notifier<DriftState> {
  @override
  DriftState build() => const DriftState();

  /// 每次进入页面都回到第一幕：读过的信不留桌面，未拆的封筒也不
  /// 替用户保管——重进即重抽，去重交给服务端（已开永久排除，
  /// 送达未开有冷却期）。
  void reset() {
    state = const DriftState();
  }

  /// 抽一封信；已有封筒在桌上时即为「换一封」。
  Future<void> draw() async {
    if (state.phase == DriftPhase.drawing) return;
    state = state.copyWith(phase: DriftPhase.drawing);
    try {
      final letter = await ref.read(driftApiProvider).next();
      state = DriftState(
        phase: DriftPhase.drawn,
        view: DriftEnvelopeView.from(letter),
      );
    } on ApiFailure catch (failure) {
      if (failure.kind == ApiErrorKind.driftPoolEmpty) {
        // 池空是叙事状态：桌面清空，交给空态卡。
        state = const DriftState(phase: DriftPhase.empty);
        return;
      }
      if (state.view != null) {
        // 换一封失败：当前这封还留在桌上，提示但不掀桌。
        state = state.copyWith(
          phase: DriftPhase.drawn,
          notice: (message: '换一封没有成功', seq: (state.notice?.seq ?? 0) + 1),
        );
        return;
      }
      state = const DriftState(phase: DriftPhase.error);
    }
  }
}
