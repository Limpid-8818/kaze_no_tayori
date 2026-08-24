/// 设置页测试：渲染结构 + 偏好开关持久化链路（load/setEnabled）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kazenotayori/app/router.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/features/settings/data/settings_repository.dart';
import 'package:kazenotayori/features/settings/providers/settings_providers.dart';
import 'package:kazenotayori/features/settings/settings_screen.dart';

void main() {
  late SharedPreferences prefs;
  late SettingsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = SettingsRepository(prefs);
  });

  Widget pumpApp() {
    final testRouter = GoRouter(
      initialLocation: Routes.settings,
      routes: [
        GoRoute(
          path: Routes.settings,
          builder: (_, _) => const SettingsScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        routerConfig: testRouter,
        theme: KazeTheme.light(),
      ),
    );
  }

  /// 从「主题随环境变化」行所在的 widget 树取 ProviderContainer，断言 provider 状态。
  ProviderContainer containerOf(WidgetTester tester) {
    final ctx = tester.element(find.text('主题随环境变化'));
    return ProviderScope.containerOf(ctx);
  }

  testWidgets('渲染：标题/组标签/偏好行齐备', (tester) async {
    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('偏好'), findsOneWidget);
    expect(find.text('主题随环境变化'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
  });

  testWidgets('默认关；点行 → 开，且持久化到 SharedPreferences', (tester) async {
    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    final container = containerOf(tester);
    expect(container.read(themeSyncProvider), isFalse);

    await tester.tap(find.text('主题随环境变化'));
    await tester.pumpAndSettle();

    expect(container.read(themeSyncProvider), isTrue);
    expect(prefs.getBool('settings.theme_sync_enabled'), isTrue);
  });

  testWidgets('再点回关，持久化可逆', (tester) async {
    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('主题随环境变化'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主题随环境变化'));
    await tester.pumpAndSettle();

    expect(prefs.getBool('settings.theme_sync_enabled'), isFalse);
  });

  testWidgets('预置 true 的持久化值 → 冷启动 load 后初始为开', (tester) async {
    await prefs.setBool('settings.theme_sync_enabled', true);
    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(themeSyncProvider), isTrue);
  });
}
