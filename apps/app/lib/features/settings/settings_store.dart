/// 设置存储 —— 设备本地轻量偏好（shared_preferences）。
///
/// 纪律（ARCHITECTURE）：不在 runApp 前等待加载。首帧一律用默认值，
/// [SettingsController.ensureLoaded] 由 AppLifecycle postFrame 异步触发，
/// 完成后经 provider 通知消费方（天色控制器等）自行过渡到真实值。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置状态。当前仅「背景自动跟随天色」一项；字段随后续设置项扩充。
class SettingsState {
  const SettingsState({this.loaded = false, this.skyAutoEnabled = true});

  /// 本地偏好是否已读入（读入前消费方按默认值渲染）。
  final bool loaded;

  /// 背景自动跟随天色。默认开启；关闭后全局回退默认昼·晴。
  final bool skyAutoEnabled;

  SettingsState copyWith({bool? loaded, bool? skyAutoEnabled}) => SettingsState(
    loaded: loaded ?? this.loaded,
    skyAutoEnabled: skyAutoEnabled ?? this.skyAutoEnabled,
  );
}

const _kSkyAutoEnabled = 'settings.sky_auto_enabled';

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  /// 幂等读入本地偏好。失败不阻断 App（按默认值继续，下次进入重试）。
  Future<void> ensureLoaded() async {
    if (state.loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        loaded: true,
        skyAutoEnabled: prefs.getBool(_kSkyAutoEnabled) ?? true,
      );
    } on Object catch (_) {
      state = state.copyWith(loaded: true);
    }
  }

  /// 开关切换：先更 UI 再落盘——落盘失败不影响本次会话体验。
  Future<void> setSkyAutoEnabled(bool value) async {
    state = state.copyWith(skyAutoEnabled: value, loaded: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSkyAutoEnabled, value);
    } on Object catch (_) {
      // 持久化失败静默：下次进入可能回到旧值，可接受
    }
  }
}
