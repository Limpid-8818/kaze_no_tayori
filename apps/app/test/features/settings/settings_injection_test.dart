import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kazenotayori/features/settings/data/settings_repository.dart';
import 'package:kazenotayori/features/settings/providers/settings_providers.dart';

void main() {
  test('模拟 main.dart ProviderScope override：Repository 注入后链路完整', () async {
    SharedPreferences.setMockInitialValues({
      'settings.theme_sync_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs);

    // 模拟 main.dart 的 ProviderScope overrides
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );

    // 1. override 生效，read 返回同一个 repo 实例
    final resolvedRepo = container.read(settingsRepositoryProvider);
    expect(resolvedRepo, same(repo));

    // 2. Repository 确实读到持久化值
    expect(await resolvedRepo.getThemeSyncEnabled(), isTrue);

    // 3. Notifier 初始值（默认 false，异步加载在 UI 层）
    expect(container.read(themeSyncProvider), isFalse);

    // 4. setEnabled 正常持久化 + 更新状态
    await container.read(themeSyncProvider.notifier).setEnabled(false);
    expect(container.read(themeSyncProvider), isFalse);
    expect(prefs.getBool('settings.theme_sync_enabled'), isFalse);

    // 5. 再次切换回 true 验证可逆
    await container.read(themeSyncProvider.notifier).setEnabled(true);
    expect(container.read(themeSyncProvider), isTrue);

    container.dispose();
  });
}
