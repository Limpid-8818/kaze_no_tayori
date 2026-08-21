/// 风信 Kaze no tayori —— 应用入口。
///
/// 启动：make app（Web / Edge）或 make app-android。
/// 冷启动先静默登录（device_id → JWT），失败不挡首帧。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/api/api_client.dart';
import 'data/api/providers.dart';
import 'data/local/secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 启动实例与 provider 暴露的必须是同一个：token 写入后消费者立即受益。
  final store = SecureStore();
  final client = ApiClient(store: store);
  await ensureSession(client);

  runApp(
    ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(client),
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
