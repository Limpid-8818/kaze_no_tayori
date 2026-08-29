/// 我的信页控制器（F6）—— LetterOwned 列表与下架/收起的编排者。
///
/// MVC 分工与 NotificationsController 一致：本类持有唯一可变状态
/// [MyLettersState]，页面只做布局与交互挂接。列表含 pending/rejected/
/// taken_down（`/v1/me/letters` 是唯一下发本人视角的入口）；下架 =
/// taken_down 非硬删，成功后本地翻状态保留在列表里；「不再显示」
/// （hide，软删位）是退场后的进一步处置，成功后本地移除。
library;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../core/letter_preview.dart';
import '../../core/relative_time.dart';
import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/letter.dart';

enum MyLettersPhase { loading, ready, empty, error }

/// 一张摘要卡的视图模型。抽取口径走共享 letter_preview（同发现列表）。
class MyLetterItemView {
  const MyLetterItemView({
    required this.id,
    required this.status,
    required this.timeLabel,
    this.poemLines = const [],
    this.previewText,
    this.placeLabel,
  });

  final String id;
  final LetterStatus status;
  final String timeLabel;
  final List<String> poemLines;
  final String? previewText;
  final String? placeLabel;

  /// 徽标文案与语义色点（NatsuColors.status* 令牌，见 natsu_colors.dart）。
  String get statusLabel => switch (status) {
    LetterStatus.pending => '审核中',
    LetterStatus.public => '公开',
    LetterStatus.rejected => '未通过',
    LetterStatus.takenDown => '已下架',
  };

  Color get statusDot => switch (status) {
    LetterStatus.pending => NatsuColors.statusWarning,
    LetterStatus.public => NatsuColors.statusSuccess,
    LetterStatus.rejected => NatsuColors.error,
    LetterStatus.takenDown => NatsuColors.statusMuted,
  };

  static MyLetterItemView from(LetterOwned letter) {
    return MyLetterItemView(
      id: letter.id,
      status: letter.status,
      timeLabel: relativeTimeLabel(letter.createdAt),
      poemLines: poemLinesOf(letter.poem),
      previewText: previewTextOf(letter),
      placeLabel: letter.placeLabel,
    );
  }

  MyLetterItemView withStatus(LetterStatus status) {
    return MyLetterItemView(
      id: id,
      status: status,
      timeLabel: timeLabel,
      poemLines: poemLines,
      previewText: previewText,
      placeLabel: placeLabel,
    );
  }
}

/// 一次性提示（视图层 ref.listen 后弹 NatsuToast）。seq 单调递增。
typedef MyLettersNotice = ({String message, int seq});

class MyLettersState {
  const MyLettersState({
    this.phase = MyLettersPhase.loading,
    this.items = const [],
    this.notice,
  });

  final MyLettersPhase phase;
  final List<MyLetterItemView> items;
  final MyLettersNotice? notice;

  MyLettersState copyWith({
    MyLettersPhase? phase,
    List<MyLetterItemView>? items,
    MyLettersNotice? notice,
  }) {
    return MyLettersState(
      phase: phase ?? this.phase,
      items: items ?? this.items,
      notice: notice ?? this.notice,
    );
  }
}

final myLettersControllerProvider =
    NotifierProvider<MyLettersController, MyLettersState>(
      MyLettersController.new,
    );

class MyLettersController extends Notifier<MyLettersState> {
  @override
  MyLettersState build() => const MyLettersState();

  /// 提示流水号放控制器字段而非 state：refresh 会整颗重建 state，
  /// 若从 state 推导，两条内容相同的提示会撞上 record 结构相等、
  /// ref.listen 不再触发。
  int _noticeSeq = 0;

  /// 进入页面 / 失败重试统一入口：清相位，加载态可见（首进无内容可保）。
  Future<void> start() async {
    state = const MyLettersState();
    try {
      final page = await ref.read(meApiProvider).myLetters(limit: 50);
      final items = [
        for (final letter in page.items) MyLetterItemView.from(letter),
      ];
      state = MyLettersState(
        phase: items.isEmpty ? MyLettersPhase.empty : MyLettersPhase.ready,
        items: items,
      );
    } on ApiFailure {
      state = const MyLettersState(phase: MyLettersPhase.error);
    }
  }

  /// 静默刷新 —— 列表留在原地不闪加载图（进度由下拉刷新的圈表达，
  /// 与 DiscoverController.refresh 同口径）。失败且已有内容时保持
  /// 原状；仅当当前没有可展示的内容时才落到 error 态。
  Future<void> refresh() async {
    try {
      final page = await ref.read(meApiProvider).myLetters(limit: 50);
      if (!ref.mounted) return;
      final items = [
        for (final letter in page.items) MyLetterItemView.from(letter),
      ];
      state = MyLettersState(
        phase: items.isEmpty ? MyLettersPhase.empty : MyLettersPhase.ready,
        items: items,
      );
    } on ApiFailure {
      if (!ref.mounted) return;
      switch (state.phase) {
        case MyLettersPhase.ready || MyLettersPhase.empty:
          break; // 手里还有列表，静默吞掉这次失败
        case MyLettersPhase.loading || MyLettersPhase.error:
          state = const MyLettersState(phase: MyLettersPhase.error);
      }
    }
  }

  /// 下架（taken_down，非硬删；回信链不塌由服务端保证）。不做乐观更新：
  /// 单次往返很快，确认段 + busy 位已防误触双发；失败只发提示，
  /// 列表原样保留，下次进来以服务端为准。
  Future<void> takeDown(String letterId) async {
    try {
      await ref.read(meApiProvider).deleteLetter(letterId);
    } on ApiFailure {
      state = state.copyWith(notice: (message: '没能下架，稍后再试', seq: ++_noticeSeq));
      return;
    }
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == letterId)
            item.withStatus(LetterStatus.takenDown)
          else
            item,
      ],
      notice: (message: '已经下架了', seq: ++_noticeSeq),
    );
  }

  /// 不再显示（hide，deleted_at 软删位；服务端保证仅已退场的信可隐藏，
  /// 公开中/审核中会 409）。成功后本地移除该项——不是翻徽标，是让它
  /// 从列表里退场；列表清空则落 empty 相态。不做乐观更新，口径同下架。
  Future<void> hide(String letterId) async {
    try {
      await ref.read(meApiProvider).hideLetter(letterId);
    } on ApiFailure {
      state = state.copyWith(notice: (message: '没能收起，稍后再试', seq: ++_noticeSeq));
      return;
    }
    final items = [
      for (final item in state.items)
        if (item.id != letterId) item,
    ];
    state = state.copyWith(
      items: items,
      phase: items.isEmpty ? MyLettersPhase.empty : null,
      notice: (message: '已经收起来了', seq: ++_noticeSeq),
    );
  }
}
