/// 风信 Kaze no tayori —— 应用入口。
///
/// 启动：make app（Web / Edge）或 make app-android。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(const ProviderScope(child: KazeApp()));
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
