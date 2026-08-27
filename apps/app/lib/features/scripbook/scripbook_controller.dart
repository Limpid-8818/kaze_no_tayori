/// 抄本页控制器（F7）—— 我收藏的信的列表与移出的编排者。
///
/// MVC 分工与 MyLettersController 一致：本类持有唯一可变状态
/// [ScripbookState]，页面只做布局与交互挂接。数据源是
/// `/v1/me/scripbook`（按收藏时间倒序的 LetterPublic，无 status——
/// 能进抄本的信都公开过，徽标不适用）。移出不是乐观更新：单次往返
/// 很快，失败时列表原样保留，下次进来以服务端为准。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/letter_preview.dart';
import '../../core/relative_time.dart';
import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/common.dart';
import '../../data/models/letter.dart';

enum ScripbookPhase { loading, ready, empty, error }

/// 一张摘要卡的视图模型。抽取口径走共享 letter_preview（同发现列表）。
class ScripbookItemView {
  const ScripbookItemView({
    required this.id,
    required this.timeLabel,
    this.poemLines = const [],
    this.previewText,
    this.placeLabel,
  });

  final String id;
  final String timeLabel;
  final List<String> poemLines;
  final String? previewText;
  final String? placeLabel;

  static ScripbookItemView from(LetterPublic letter) {
    return ScripbookItemView(
      id: letter.id,
      timeLabel: relativeTimeLabel(letter.createdAt),
      poemLines: poemLinesOf(letter.poem),
      previewText: previewTextOf(letter),
      placeLabel: letter.placeLabel,
    );
  }
}

/// 一次性提示（视图层 ref.listen 后弹 NatsuToast）。seq 单调递增。
typedef ScripbookNotice = ({String message, int seq});

class ScripbookState {
  const ScripbookState({
    this.phase = ScripbookPhase.loading,
    this.items = const [],
    this.notice,
  });

  final ScripbookPhase phase;
  final List<ScripbookItemView> items;
  final ScripbookNotice? notice;

  ScripbookState copyWith({
    ScripbookPhase? phase,
    List<ScripbookItemView>? items,
    ScripbookNotice? notice,
  }) {
    return ScripbookState(
      phase: phase ?? this.phase,
      items: items ?? this.items,
      notice: notice ?? this.notice,
    );
  }
}

final scripbookControllerProvider =
    NotifierProvider<ScripbookController, ScripbookState>(
      ScripbookController.new,
    );

class ScripbookController extends Notifier<ScripbookState> {
  @override
  ScripbookState build() => const ScripbookState();

  /// 提示流水号放控制器字段而非 state（同我的信）：两条内容相同的
  /// 提示不能因 record 结构相等而让 ref.listen 沉默。
  int _noticeSeq = 0;

  /// 进入页面 / 失败重试统一入口：清相位，加载态可见（首进无内容可保）。
  Future<void> start() async {
    state = const ScripbookState();
    try {
      final page = await ref.read(meApiProvider).scripbook(limit: 50);
      _apply(page);
    } on ApiFailure {
      if (!ref.mounted) return;
      state = const ScripbookState(phase: ScripbookPhase.error);
    }
  }

  /// 静默刷新 —— 列表留在原地不闪加载图。失败且已有内容时保持原状；
  /// 仅当当前没有可展示的内容时才落到 error 态。
  Future<void> refresh() async {
    try {
      final page = await ref.read(meApiProvider).scripbook(limit: 50);
      if (!ref.mounted) return;
      _apply(page);
    } on ApiFailure {
      if (!ref.mounted) return;
      switch (state.phase) {
        case ScripbookPhase.ready || ScripbookPhase.empty:
          break; // 手里还有列表，静默吞掉这次失败
        case ScripbookPhase.loading || ScripbookPhase.error:
          state = const ScripbookState(phase: ScripbookPhase.error);
      }
    }
  }

  /// 移出抄本。不做乐观更新：确认段 + busy 位已防误触双发；失败只发
  /// 提示，列表原样保留。移出后仍能再收回来（add 幂等），但已读过的
  /// 信不会再漂流回来——这条代价由操作区的两段式确认讲清。
  Future<void> remove(String letterId) async {
    try {
      await ref.read(meApiProvider).removeScripbook(letterId);
    } on ApiFailure {
      state = state.copyWith(notice: (message: '没能移出，稍后再试', seq: ++_noticeSeq));
      return;
    }
    state = state.copyWith(
      phase: state.items.length == 1 ? ScripbookPhase.empty : state.phase,
      items: [
        for (final item in state.items)
          if (item.id != letterId) item,
      ],
      notice: (message: '已经把它放归风里', seq: ++_noticeSeq),
    );
  }

  void _apply(Page<LetterPublic> page) {
    final items = [
      for (final letter in page.items) ScripbookItemView.from(letter),
    ];
    state = ScripbookState(
      phase: items.isEmpty ? ScripbookPhase.empty : ScripbookPhase.ready,
      items: items,
    );
  }
}
