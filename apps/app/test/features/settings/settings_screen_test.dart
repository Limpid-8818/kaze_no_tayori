/// 设置页只展示真实能力；尚未接入的主题同步不得伪装成可用开关。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kazenotayori/app/router.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/features/settings/settings_screen.dart';

void main() {
  testWidgets('未接入的主题同步不渲染成可用开关', (tester) async {
    final router = GoRouter(
      initialLocation: Routes.settings,
      routes: [
        GoRoute(
          path: Routes.settings,
          builder: (_, _) => const SettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: KazeTheme.light()),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.textContaining('真正接入后出现'), findsOneWidget);
    expect(find.text('主题随环境变化'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });
}
