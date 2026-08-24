import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kazenotayori/features/settings/data/settings_repository.dart';
import 'package:kazenotayori/features/settings/providers/settings_providers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('build 返回默认值 false', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(prefs)),
      ],
    );

    expect(container.read(themeSyncProvider), isFalse);
    container.dispose();
  });

  test('Repository 中有值时 Notifier 初始值仍为 false（异步加载在 UI 层）', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.theme_sync_enabled', true);

    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(prefs)),
      ],
    );

    // Notifier 同步返回默认值，真实值由 SettingsScreen.initState 异步加载
    expect(container.read(themeSyncProvider), isFalse);
    container.dispose();
  });

  test('setEnabled(true) 持久化并更新状态', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(prefs)),
      ],
    );

    expect(container.read(themeSyncProvider), isFalse);

    await container.read(themeSyncProvider.notifier).setEnabled(true);
    expect(container.read(themeSyncProvider), isTrue);
    expect(prefs.getBool('settings.theme_sync_enabled'), isTrue);
    container.dispose();
  });

  test('setEnabled(false) 持久化并更新状态', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(prefs)),
      ],
    );

    // 先设为 true
    await container.read(themeSyncProvider.notifier).setEnabled(true);
    expect(container.read(themeSyncProvider), isTrue);

    // 再设为 false
    await container.read(themeSyncProvider.notifier).setEnabled(false);
    expect(container.read(themeSyncProvider), isFalse);
    expect(prefs.getBool('settings.theme_sync_enabled'), isFalse);
    container.dispose();
  });

  test('多次切换状态，最终值与最后一次一致', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(prefs)),
      ],
    );

    final notifier = container.read(themeSyncProvider.notifier);

    await notifier.setEnabled(true);
    expect(container.read(themeSyncProvider), isTrue);

    await notifier.setEnabled(false);
    expect(container.read(themeSyncProvider), isFalse);

    await notifier.setEnabled(true);
    expect(container.read(themeSyncProvider), isTrue);

    container.dispose();
  });
}
