/// 读信页控制器 —— 加载、开信上报、共鸣乐观回显、举报。
///
/// MVC 分工与 WriteController 一致：页面只做布局与交互挂接，本类持有
/// 唯一可变状态 [ReaderState]。按 letterId 分实例（family）：读信页可以
/// 叠栈（看原信/告知跳转），每页各持各的信，互不覆盖；页面离栈即无
/// 监听，实例自动销毁，再进入总是全新加载。共鸣是一次性动作：已共鸣
/// 位由详情接口 me_resonated 下发并随加载播种（重进常亮），会话内先
/// 落章再用服务端计数校正，失败回滚；服务端幂等，重复按也涨不了计数。
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

  /// 已共鸣（详情 me_resonated 播种 + 会话内乐观位，随校正保留）。
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

/// 页面持有监听期间保留；对应 Reader 离栈后自动释放，避免 family 按信件
/// 数量永久累积状态。
final readerControllerProvider = NotifierProvider.autoDispose
    .family<ReaderController, ReaderState, String>(ReaderController.new);

class ReaderController extends Notifier<ReaderState> {
  ReaderController(this.arg);

  /// 本实例服务的信（family 参数）——start 与全部动作都以它为准。
  final String arg;

  @override
  ReaderState build() => const ReaderState();

  /// 进入页面时调用（可重复调用 = 重试）。
  Future<void> start() async {
    state = const ReaderState();
    await _load();
  }

  Future<void> retry() => _load();

  Future<void> _load() async {
    final api = ref.read(lettersApiProvider);
    try {
      final letter = await api.get(arg);
      if (!ref.mounted) return;
      final view = LetterView.from(letter);
      state = state.copyWith(
        phase: ReaderPhase.ready,
        view: view,
        resonated: view.resonated,
        resonanceCount: view.resonanceCount,
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: failure.kind == ApiErrorKind.notFound
            ? ReaderPhase.notFound
            : ReaderPhase.error,
      );
      return;
    }
    // 开信上报不阻断阅读：失败静默（幂等，下次打开还有机会）。
    try {
      await api.markRead(arg);
    } on ApiFailure {
      // 故意忽略
    }
  }

  /// ✦ 共鸣：先落章再上报，用服务端计数校正；失败回滚。
  Future<void> resonate() async {
    if (state.phase != ReaderPhase.ready || state.resonated) return;

    final before = state.resonanceCount;
    state = state.copyWith(resonated: true, resonanceCount: before + 1);
    try {
      final res = await ref.read(lettersApiProvider).addResonance(arg);
      if (!ref.mounted) return;
      // 服务端为真源，但只在有出入时校正——乐观值碰巧等于真值就不必
      // 重建一帧，句子也免得白白淡变一次
      if (res.resonanceCount != state.resonanceCount) {
        state = state.copyWith(resonanceCount: res.resonanceCount);
      }
    } on ApiFailure {
      if (!ref.mounted) return;
      state = state.copyWith(
        resonated: false,
        resonanceCount: before,
        notice: (message: '没有成功，再试一次', seq: (state.notice?.seq ?? 0) + 1),
      );
    }
  }

  /// 记入抄本（PRD 6.10，个人行为）。服务端幂等（PK 冲突忽略、
  /// saved_count 不重复加），且「是否已收藏」不下发——菜单项恒可点，
  /// 重复记一次只是再听到一声回响。
  Future<void> saveToScripbook() async {
    try {
      await ref
          .read(meApiProvider)
          .addScripbook(ScripbookAddRequest(letterId: arg));
      if (!ref.mounted) return;
      state = state.copyWith(
        notice: (message: '已收进抄本', seq: (state.notice?.seq ?? 0) + 1),
      );
    } on ApiFailure {
      if (!ref.mounted) return;
      state = state.copyWith(
        notice: (message: '没能收进抄本，再试一次', seq: (state.notice?.seq ?? 0) + 1),
      );
    }
  }

  /// 举报。理由由页面弹层收集（≤32 字）。
  Future<void> report({required String reason, String? detail}) async {
    try {
      await ref
          .read(lettersApiProvider)
          .report(arg, ReportRequest(reason: reason, detail: detail));
      if (!ref.mounted) return;
      state = state.copyWith(
        notice: (message: '已举报', seq: (state.notice?.seq ?? 0) + 1),
      );
    } on ApiFailure {
      if (!ref.mounted) return;
      state = state.copyWith(
        notice: (message: '没有成功，再试一次', seq: (state.notice?.seq ?? 0) + 1),
      );
    }
  }
}
