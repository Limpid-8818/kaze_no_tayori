/// 路由：登录守卫 + 工作台壳 + INITIAL_ROUTE 调试直通车。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/feedback/feedback_screen.dart';
import '../features/letters/letters_screen.dart';
import '../features/login/login_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/review/review_screen.dart';
import '../features/review/review_detail_screen.dart';
import '../features/seed/seed_screen.dart';
import 'admin_auth.dart' show adminAuthProvider;
import 'shell.dart';

abstract final class AdminRoutes {
  static const login = '/login';
  static const dashboard = '/';
  static const review = '/review';
  static const reviewDetail = '/review/:id';
  static const letters = '/letters';
  static const reports = '/reports';
  static const feedback = '/feedback';
  static const seed = '/seed';

  static String reviewDetailOf(String id) => '/review/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(adminAuthProvider);
  return GoRouter(
    // 调试直通车：--dart-define=INITIAL_ROUTE=/review/<id> 直达深页
    initialLocation: const String.fromEnvironment(
      'INITIAL_ROUTE',
      defaultValue: AdminRoutes.dashboard,
    ),
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.loggedIn;
      final goingLogin = state.matchedLocation == AdminRoutes.login;
      if (!loggedIn) return goingLogin ? null : AdminRoutes.login;
      if (goingLogin) return AdminRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AdminRoutes.login, builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: AdminRoutes.dashboard,
            builder: (_, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: AdminRoutes.review,
            builder: (_, _) => const ReviewScreen(),
          ),
          GoRoute(
            path: AdminRoutes.reviewDetail,
            builder: (_, state) =>
                ReviewDetailScreen(letterId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AdminRoutes.letters,
            builder: (_, _) => const LettersScreen(),
          ),
          GoRoute(
            path: AdminRoutes.reports,
            builder: (_, _) => const ReportsScreen(),
          ),
          GoRoute(
            path: AdminRoutes.feedback,
            builder: (_, _) => const FeedbackScreen(),
          ),
          GoRoute(
            path: AdminRoutes.seed,
            builder: (_, _) => const SeedScreen(),
          ),
        ],
      ),
    ],
  );
});
