/// 全局天色控制器 —— 「天色联动」的单一事实来源。
///
/// 合成优先级：debug 强制档（SKY_FORCE）> 用户关闭（固定昼·晴）>
/// 自动档（当地天气 × 本地时段）。各依赖就绪前一律落到时段·晴——
/// 「先按时间段·晴渲染」，天气到达后由消费端以 drift 曲线平滑过渡。
///
/// 前台实时性：分钟级 ticker 捕捉时段跨越；天气随定位刷新链路
/// （回前台 refreshIfActive）经 [homeEnvironmentControllerProvider]
/// 流入。所有档位端点都是令牌层 const 预设，插值只在渲染层发生。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show LinearGradient;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../features/settings/settings_store.dart';
import '../theme.dart';
import 'home_environment_controller.dart';

/// 当前天色档 —— 字段级相等：档位没换就不触发动画。
class SkyState {
  const SkyState({required this.weather, required this.daypart});

  final KazeWeather weather;
  final KazeDaypart daypart;

  LinearGradient get gradient => KazeSky.of(weather, daypart);

  @override
  bool operator ==(Object other) =>
      other is SkyState && other.weather == weather && other.daypart == daypart;

  @override
  int get hashCode => Object.hash(weather, daypart);

  @override
  String toString() => 'SkyState($weather, $daypart)';
}

final skyControllerProvider = NotifierProvider<SkyController, SkyState>(
  SkyController.new,
);

class SkyController extends Notifier<SkyState> {
  /// 时钟注入口 —— 测试换成固定时刻/快进。
  DateTime Function() clock = DateTime.now;

  Timer? _ticker;

  @override
  SkyState build() {
    // 沿 homeEnvironment 先例：listen 挪进 microtask，不在 build 期同步挂
    Future.microtask(() {
      ref.listen<SettingsState>(settingsProvider, (_, _) => _recompute());
      ref.listen<HomeEnvironmentState>(
        homeEnvironmentControllerProvider,
        (_, _) => _recompute(),
      );
      // 挂上 listen 之前落到依赖里的变更为这里补齐（重推幂等）
      _recompute();
    });

    _startTicker();
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
    });

    return _resolve();
  }

  /// 回前台强制重算（跨时段追认 + 认领刚刷新完的天气）。
  void refresh() => _recompute();

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(minutes: 1), (_) => _recompute());
  }

  void _recompute() {
    final next = _resolve();
    if (next != state) state = next;
  }

  SkyState _resolve() {
    // debug 强制档最高优先：验收黄昏/雨夜不用等真实时间
    if (kDebugMode) {
      final forced = KazeSky.parseForce(Env.skyForce);
      if (forced != null) {
        return SkyState(weather: forced.$1, daypart: forced.$2);
      }
    }

    // 关闭自动联动 → 全局固定昼·晴（加载完成前按默认「开」渲染）
    final settings = ref.read(settingsProvider);
    if (settings.loaded && !settings.skyAutoEnabled) {
      return const SkyState(
        weather: KazeWeather.sunny,
        daypart: KazeDaypart.noon,
      );
    }

    // 自动档：天气取不到就是晴兜底，时段恒可从本地时钟推导
    final icon = ref.read(homeEnvironmentControllerProvider).weather?.icon;
    return SkyState(
      weather: KazeSky.fromIcon(icon),
      daypart: KazeSky.daypartOf(clock()),
    );
  }
}
