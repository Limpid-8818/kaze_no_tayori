/// 风信 Kaze no tayori —— 应用入口。
///
/// 启动：make app（Web）、make app-android 或 make app-ios。
/// 首帧绘制后再静默登录（device_id → JWT），离线不会阻塞应用壳。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'app/app_lifecycle.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/api/providers.dart';
import 'data/local/secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = SecureStore();
  // mock 开关（USE_MOCK_API）在这里与 provider 层同规则分叉
  final client = createApiClient(store: store);

  runApp(
    ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(client),
      ],
      child: const KazeApp(),
    ),
  );

  // UI 不依赖会话是否已换到 JWT；后续请求遇到 401 也会自动重绑。
  // 放到首帧之后启动，避免离线时网络超时把启动页卡住。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(ensureSession(client));
  });
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
      builder: (context, child) => AppLifecycle(child: child!),
    );
  }
}
