/// 设置页 Riverpod providers。
///
/// ThemeSyncNotifier 是纯同步状态机：build 返回默认值 false，
/// 异步加载真实值的职责在 SettingsScreen.initState 中完成。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

/// SettingsRepository 实例。
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError(
    'settingsRepositoryProvider 必须由测试或主应用通过 overrideWithValue 注入。',
  );
});

/// 主题同步开关状态（纯同步，默认 false）。
final themeSyncProvider = NotifierProvider<ThemeSyncNotifier, bool>(
  ThemeSyncNotifier.new,
);

class ThemeSyncNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> setEnabled(bool value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setThemeSyncEnabled(value);
    state = value;
  }
}
