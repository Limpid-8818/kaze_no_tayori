/// 关于页：信纸卡内容、三张素材图与 pubspec 版本号展示。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:kazenotayori/app/router.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/features/about/about_screen.dart';

import '../../fakes/frozen_home_environment.dart';

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: '风信',
      packageName: 'com.aisquare.kazenotayori',
      version: '9.9.9',
      buildNumber: '99',
      buildSignature: '',
    );
  });

  GoRouter buildRouter() {
    final router = GoRouter(
      initialLocation: Routes.about,
      routes: [
        GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
      ],
    );
    addTearDown(router.dispose);
    return router;
  }

  Future<void> pumpAbout(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [frozenHomeEnvironmentOverride],
        child: MaterialApp.router(
          routerConfig: buildRouter(),
          theme: KazeTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('展示品牌、致谢、团队、灵感来源与版本号', (tester) async {
    await pumpAbout(tester);

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('风信'), findsOneWidget);
    expect(find.text('KAZE NO TAYORI'), findsOneWidget);
    expect(find.text('v9.9.9'), findsOneWidget);
    expect(find.text('谢谢你，愿意把思绪交给风。'), findsOneWidget);
    expect(find.text('开发团队'), findsOneWidget);
    expect(find.text('Ai²'), findsOneWidget);
    expect(find.text('大工黑客松 S2 · 制造一点意外'), findsOneWidget);
    expect(find.text('灵感来源'), findsOneWidget);
    expect(find.text('INSPIRED BY'), findsOneWidget);
    expect(find.text('ヨルシカ《二人称》'), findsOneWidget);
    expect(find.text('2026 · 夏'), findsOneWidget);
  });

  testWidgets('三张画布素材图正确挂载', (tester) async {
    await pumpAbout(tester);

    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((asset) => asset.assetName)
        .toList();

    expect(
      assetNames,
      containsAll([
        'assets/images/app_logo.png',
        'assets/images/team_logo.png',
        'assets/images/album_yorushika.png',
      ]),
    );
  });

  testWidgets('不渲染衬线 slogan（已按要求裁剪）', (tester) async {
    await pumpAbout(tester);

    expect(find.text('让作品先于作者抵达'), findsNothing);
  });
}
