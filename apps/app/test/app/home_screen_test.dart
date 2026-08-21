/// Home 页测试：时段推导纯函数 + 导航/抽屉 widget 行为 + 干净度守卫。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kazenotayori/app/home_screen.dart';
import 'package:kazenotayori/app/router.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/core/day_period.dart';

void main() {
  group('dayPeriodOf 边界', () {
    test('四时段切换点', () {
      expect(dayPeriodOf(DateTime(2026, 8, 21, 4, 59)), KazeDayPeriod.night);
      expect(dayPeriodOf(DateTime(2026, 8, 21, 5)), KazeDayPeriod.morning);
      expect(dayPeriodOf(DateTime(2026, 8, 21, 10, 59)), KazeDayPeriod.morning);
      expect(dayPeriodOf(DateTime(2026, 8, 21, 11)), KazeDayPeriod.noon);
      expect(dayPeriodOf(DateTime(2026, 8, 21, 16, 59)), KazeDayPeriod.noon);
      expect(dayPeriodOf(DateTime(2026, 8, 21, 17)), KazeDayPeriod.evening);
      expect(dayPeriodOf(DateTime(2026, 8, 21, 21, 59)), KazeDayPeriod.evening);
      expect(dayPeriodOf(DateTime(2026, 8, 21, 22)), KazeDayPeriod.night);
      expect(dayPeriodOf(DateTime(2026, 8, 21, 23, 59)), KazeDayPeriod.night);
    });

    test('问候语与时段标签覆盖四段', () {
      for (final period in KazeDayPeriod.values) {
        expect(greetingFor(period), isNotEmpty);
        expect(dayPeriodLabel(period).length, 1);
      }
      expect(greetingFor(KazeDayPeriod.morning), '早上好');
      expect(dayPeriodLabel(KazeDayPeriod.night), '夜');
    });
  });

  group('HomeScreen', () {
    // 固定中午，问候语可断言
    final fixedNow = DateTime(2026, 8, 21, 12);

    Widget pumpApp() {
      final testRouter = GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (_, _) => HomeScreen(now: fixedNow),
          ),
          _stubRoute(Routes.drift, 'drift'),
          _stubRoute(Routes.discover, 'discover'),
          _stubRoute(Routes.write, 'write'),
          _stubRoute(Routes.myLetters, 'my-letters'),
          _stubRoute(Routes.scripbook, 'scripbook'),
          _stubRoute(Routes.notifications, 'notifications'),
          _stubRoute(Routes.settings, 'settings'),
          _stubRoute(Routes.about, 'about'),
        ],
      );
      return MaterialApp.router(
        routerConfig: testRouter,
        theme: KazeTheme.light(),
      );
    }

    testWidgets('问候语按注入时钟、三张入口卡齐备', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KazeTheme.light(),
          home: HomeScreen(now: fixedNow),
        ),
      );
      expect(find.text('中午好'), findsOneWidget);
      expect(find.text('把此刻写下来，寄给远方'), findsWidgets);
      expect(find.text('随机漂流'), findsOneWidget);
      expect(find.text('就地发掘'), findsOneWidget);
      expect(find.text('写一封信'), findsOneWidget);
      // 环境行：时段芯片
      expect(find.text('昼'), findsOneWidget);
    });

    testWidgets('三张卡各自导航', (tester) async {
      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      // 这里直接验证卡片路由跳转（HomeScreen 内部用 DateTime.now()，
      // 导航断言不受时钟影响）
      await tester.tap(find.text('随机漂流'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('drift')), findsOneWidget);

      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('就地发掘'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('discover')), findsOneWidget);
    });

    testWidgets('抽屉导航与关于入口', (tester) async {
      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // 品牌区与导航项可见
      expect(find.text('我的信'), findsOneWidget);
      expect(find.text('抄本'), findsOneWidget);
      expect(find.text('回信告知'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('关于风信'), findsOneWidget);

      // 点设置 → 抽屉收起并跳转
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings')), findsOneWidget);

      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      // 关于风信 → /about 占位
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关于风信'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('about')), findsOneWidget);
    });

    testWidgets('干净度守卫：无品牌角标、无抽屉底注、无连通性卡片', (tester) async {
      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      // AppBar 右上角无「风信」字样（唯一「风信」在抽屉品牌区，抽屉未开时不可见）
      expect(find.text('风信'), findsNothing);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // 抽屉打开后品牌区恰一处；底部无 tagline 文本
      expect(find.text('风信'), findsOneWidget);
      expect(find.text('匿名 · 漂流 · 不追踪'), findsNothing);
      expect(find.textContaining('后端连通性'), findsNothing);
      // 左上角无关闭按钮（点遮罩/边缘滑动即可收起）
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}

/// 桩路由：目标页挂 Key，跳转断言用。
GoRoute _stubRoute(String path, String key) {
  return GoRoute(
    path: path,
    builder: (_, _) => Scaffold(
      key: Key(key),
      body: Center(child: Text(key)),
    ),
  );
}
