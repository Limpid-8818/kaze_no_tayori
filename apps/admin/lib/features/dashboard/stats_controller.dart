/// 统计概览的共享数据源。
///
/// Dashboard 是展示者，工作台壳是角标消费者——两者共用本 controller，
/// 谁先进入页面谁触发 start()，其余方只读现值（操作后经 refresh() 静默刷新）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/admin.dart';

enum StatsPhase { loading, ready, error }

class StatsState {
  const StatsState({this.phase = StatsPhase.loading, this.stats});

  final StatsPhase phase;
  final AdminStats? stats;

  StatsState copyWith({StatsPhase? phase, AdminStats? stats}) =>
      StatsState(phase: phase ?? this.phase, stats: stats ?? this.stats);
}

class StatsController extends Notifier<StatsState> {
  @override
  StatsState build() => const StatsState();

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
  }

  /// 失败且已有内容时保持原状（静默刷新）。
  Future<void> refresh() async {
    try {
      final stats = await ref.read(adminApiProvider).stats();
      if (!ref.mounted) return;
      state = StatsState(phase: StatsPhase.ready, stats: stats);
    } on ApiFailure {
      if (!ref.mounted) return;
      final hasContent = state.stats != null;
      state = state.copyWith(
        phase: hasContent ? StatsPhase.ready : StatsPhase.error,
      );
    }
  }
}

final statsControllerProvider = NotifierProvider<StatsController, StatsState>(
  StatsController.new,
);
