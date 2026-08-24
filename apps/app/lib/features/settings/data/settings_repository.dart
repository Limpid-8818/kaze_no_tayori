/// 用户偏好的本地读写层（SharedPreferences）。
///
/// 仅存非敏感设置；auth token 继续走 SecureStore。
library;

import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kThemeSync = 'settings.theme_sync_enabled';

  /// 主题是否随场景变化（默认关闭）。
  Future<bool> getThemeSyncEnabled() async =>
      _prefs.getBool(_kThemeSync) ?? false;

  Future<void> setThemeSyncEnabled(bool value) async =>
      await _prefs.setBool(_kThemeSync, value);
}
