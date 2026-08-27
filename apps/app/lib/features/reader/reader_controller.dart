/// 读信页控制器 —— 加载、开信上报、共鸣乐观回显、举报。
///
/// MVC 分工与 WriteController 一致：页面只做布局与交互挂接，本类持有
/// 唯一可变状态 [ReaderState]。共鸣是一次性动作：本地先落章再用服务端
/// 计数校正，失败回滚；不持久化 resonated 位——服务端幂等，重复进入
/// 这封信再按一次也涨不了计数。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/common.dart';
import 'letter_view.dart';

/// 一次性提示（视图层 ref.listen 后弹 NatsuToast）。seq 单调递增。
typedef ReaderNotice = ({String message, int seq});

enum ReaderPhase { loading, ready, notFound, error }

class ReaderState {
  const ReaderState({
    this.phase = ReaderPhase.loading,
    this.view,
    this.resonated = false,
    this.resonanceCount = 0,
    this.notice,
  });

  final ReaderPhase phase;

  /// ready 态才有；其余态为 null。
  final LetterView? view;

  /// 本会话内已共鸣（乐观位，随校正保留）。
  final bool resonated;
  final int resonanceCount;
  final ReaderNotice? notice;

  ReaderState copyWith({
    ReaderPhase? phase,
    Object? view = _unset,
    bool? resonated,
    int? resonanceCount,
    ReaderNotice? notice,
  }) {
    return ReaderState(
      phase: phase ?? this.phase,
      view: view == _unset ? this.view : view as LetterView?,
      resonated: resonated ?? this.resonated,
      resonanceCount: resonanceCount ?? this.resonanceCount,
      notice: notice ?? this.notice,
    );
  }

  static const _unset = Object();
}

final readerControllerProvider =
    NotifierProvider<ReaderController, ReaderState>(ReaderController.new);

class ReaderController extends Notifier<ReaderState> {
  @override
  ReaderState build() => const ReaderState();

  String? _letterId;

  /// 进入页面时调用（可重复调用 = 重试）。
  Future<void> start(String letterId) async {
    _letterId = letterId;
    state = const ReaderState();
    await _load();
  }

  Future<void> retry() => _load();

  Future<void> _load() async {
    final letterId = _letterId;
    if (letterId == null) return;
    final api = ref.read(lettersApiProvider);
    try {
      final letter = await api.get(letterId);
      final view = LetterView.from(letter);
      state = state.copyWith(
        phase: ReaderPhase.ready,
        view: view,
        resonanceCount: view.resonanceCount,
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        phase: failure.kind == ApiErrorKind.notFound
            ? ReaderPhase.notFound
            : ReaderPhase.error,
      );
      return;
    }
    // 开信上报不阻断阅读：失败静默（幂等，下次打开还有机会）。
    try {
      await api.markRead(letterId);
    } on ApiFailure {
      // 故意忽略
    }
  }

  /// ✦ 共鸣：先落章再上报，用服务端计数校正；失败回滚。
  Future<void> resonate() async {
    if (state.phase != ReaderPhase.ready || state.resonated) return;
    final letterId = _letterId;
    if (letterId == null) return;

    final before = state.resonanceCount;
    state = state.copyWith(resonated: true, resonanceCount: before + 1);
    try {
      final res = await ref.read(lettersApiProvider).addResonance(letterId);
      state = state.copyWith(resonanceCount: res.resonanceCount);
    } on ApiFailure {
      state = state.copyWith(
        resonated: false,
        resonanceCount: before,
        notice: (message: '没有成功，再试一次', seq: (state.notice?.seq ?? 0) + 1),
      );
    }
  }

  /// 举报。理由由页面弹层收集（≤32 字）。
  Future<void> report({required String reason, String? detail}) async {
    final letterId = _letterId;
    if (letterId == null) return;
    try {
      await ref
          .read(lettersApiProvider)
          .report(letterId, ReportRequest(reason: reason, detail: detail));
      state = state.copyWith(
        notice: (message: '已举报', seq: (state.notice?.seq ?? 0) + 1),
      );
    } on ApiFailure {
      state = state.copyWith(
        notice: (message: '没有成功，再试一次', seq: (state.notice?.seq ?? 0) + 1),
      );
    }
  }
}
