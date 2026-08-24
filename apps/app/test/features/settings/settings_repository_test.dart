import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kazenotayori/features/settings/data/settings_repository.dart';

void main() {
  late SettingsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = SettingsRepository(prefs);
  });

  test('首次读取返回默认值 false', () async {
    expect(await repo.getThemeSyncEnabled(), isFalse);
  });

  test('写入 true 后读取返回 true', () async {
    await repo.setThemeSyncEnabled(true);
    expect(await repo.getThemeSyncEnabled(), isTrue);
  });

  test('写入 false 后读取返回 false', () async {
    await repo.setThemeSyncEnabled(false);
    expect(await repo.getThemeSyncEnabled(), isFalse);
  });

  test('多次写入互不影响，最终值与最后一次一致', () async {
    await repo.setThemeSyncEnabled(true);
    await repo.setThemeSyncEnabled(false);
    await repo.setThemeSyncEnabled(true);
    expect(await repo.getThemeSyncEnabled(), isTrue);
  });
}
