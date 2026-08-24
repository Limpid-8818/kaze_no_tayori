/// 风信 Kaze no tayori —— 应用入口。
///
/// 启动：make app（Web / Edge）或 make app-android。
/// 冷启动先静默登录（device_id → JWT），失败不挡首帧。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/bootstrap.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/api/api_client.dart';
import 'data/api/providers.dart';
import 'data/local/secure_store.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = SecureStore();
  final client = ApiClient(store: store);
  await ensureSession(client);

  // 初始化 SharedPreferences 并注入 SettingsRepository，
  // 使 settingsRepositoryProvider 在生产环境可用。
  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);

  runApp(
    ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(client),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
      ],
      child: const KazeApp(),
    ),
  );
}

class KazeApp extends StatelessWidget {
  const KazeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '风信',
      debugShowCheckedModeBanner: false,
      theme: KazeTheme.light(),
      routerConfig: router,
    );
  }
}
