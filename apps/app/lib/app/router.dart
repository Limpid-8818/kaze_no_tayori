/// 路由表（go_router）。
///
/// 路径命名对齐产品语言而非技术语言：`/drift` 是「随机漂流」，`/discover` 是
/// 「就地发掘」，`/write` 是写信流。回信复用写信流，只是多带一个 parent。
///
/// **刻意不存在的路由**：作者主页、关注列表、热门榜、私信会话（见根 CLAUDE.md §2）。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/about/about_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/drift/drift_screen.dart';
import '../features/feedback/feedback_screen.dart';
import '../features/my_letters/my_letters_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/scripbook/scripbook_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/write/write_screen.dart';
import 'home_screen.dart';

/// 页面返回感知（如发掘页从阅读器回来要整页重刷）。挂到 router 的
/// observers 上，页面用 RouteAware 订阅。
final routeObserver = RouteObserver<ModalRoute<Object?>>();

abstract final class Routes {
  static const home = '/';
  static const write = '/write';
  static const drift = '/drift';
  static const discover = '/discover';
  static const reader = '/letters/:id';
  static const myLetters = '/me/letters';
  static const scripbook = '/me/scripbook';
  static const notifications = '/me/notifications';
  static const settings = '/settings';
  static const feedback = '/feedback';
  static const about = '/about';

  static String readerOf(String id) => '/letters/$id';
}

final router = GoRouter(
  // 调试直通车：--dart-define=INITIAL_ROUTE=/letters/<id> 可直接打开
  // 尚没有 UI 入口的页面（如 F3 阅读器，入口在 F4 才接上）。默认首页。
  initialLocation: const String.fromEnvironment(
    'INITIAL_ROUTE',
    defaultValue: Routes.home,
  ),
  observers: [routeObserver],
  routes: [
    GoRoute(path: Routes.home, builder: (_, _) => HomeScreen()),

    // 写信流。带 parent 时即为「回以一封信」（回信是独立作品，不是私信）
    GoRoute(
      path: Routes.write,
      builder: (_, state) =>
          WriteScreen(parentLetterId: state.uri.queryParameters['parent']),
    ),

    // 两条收信入口，并列的一等公民
    GoRoute(path: Routes.drift, builder: (_, _) => const DriftScreen()),
    GoRoute(path: Routes.discover, builder: (_, _) => const DiscoverScreen()),

    GoRoute(
      path: Routes.reader,
      builder: (_, state) =>
          ReaderScreen(letterId: state.pathParameters['id']!),
    ),

    GoRoute(path: Routes.myLetters, builder: (_, _) => const MyLettersScreen()),
    GoRoute(path: Routes.scripbook, builder: (_, _) => const ScripbookScreen()),
    GoRoute(
      path: Routes.notifications,
      builder: (_, _) => const NotificationsScreen(),
    ),
    GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),

    // 反馈：设置页入口；未来并入「帮助与反馈」独立入口
    GoRoute(path: Routes.feedback, builder: (_, _) => const FeedbackScreen()),

    // 关于页：一张信纸卡承载品牌、致谢与出处（版本号读 pubspec）
    GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
  ],
);
