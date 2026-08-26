/// Home 页测试：时段推导纯函数 + 导航/抽屉 widget 行为 + 环境行三芯片 + 干净度守卫。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kazenotayori/app/home_screen.dart';
import 'package:kazenotayori/app/router.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/core/day_period.dart';
import 'package:kazenotayori/data/api/geo_api.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/data/api/weather_api.dart';
import 'package:kazenotayori/data/device/location_gateway.dart';
import 'package:kazenotayori/data/models/letter.dart';
import 'package:kazenotayori/app/controllers/location_controller.dart';
import 'package:kazenotayori/app/controllers/permission_controller.dart';
import 'package:kazenotayori/app/permissions/app_permission.dart';

// ---- 测试替身 ----

class _FakePermissionGateway implements PermissionGateway {
  _FakePermissionGateway({required this.status});

  final AppPermissionStatus status;

  @override
  Future<AppPermissionStatus> check(AppPermission permission) async => status;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async => status;

  @override
  Future<bool> openSettings() async => true;
}

class _FakeLocationGateway implements LocationGateway {
  _FakeLocationGateway({required this.serviceEnabled});

  bool serviceEnabled;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<GeoCoordinate> current() async {
    return GeoCoordinate(
      latitude: 24.4798,
      longitude: 118.0894,
      accuracyM: 12,
      measuredAt: DateTime(2026, 8, 25),
    );
  }
}

class _FakeWeatherApi implements WeatherApi {
  _FakeWeatherApi({this.result});

  final Weather? result;

  @override
  Future<Weather?> getCurrentWeather(double lat, double lon) async => result;
}

class _FakeGeoApi implements GeoApi {
  _FakeGeoApi({this.result});

  final String? result;

  @override
  Future<String?> reverse(double lat, double lon) async => result;
}

// ---- 容器工厂 ----

ProviderScope _envScope({
  AppPermissionStatus permissionStatus = AppPermissionStatus.denied,
  bool serviceEnabled = true,
  String? geoResult,
  Weather? weatherResult,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      permissionGatewayProvider.overrideWithValue(
        _FakePermissionGateway(status: permissionStatus),
      ),
      locationGatewayProvider.overrideWithValue(
        _FakeLocationGateway(serviceEnabled: serviceEnabled),
      ),
      geoApiProvider.overrideWithValue(_FakeGeoApi(result: geoResult)),
      weatherApiProvider.overrideWithValue(
        _FakeWeatherApi(result: weatherResult),
      ),
    ],
    child: child,
  );
}

// ---- 测试 ----

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

    Widget pumpApp({
      AppPermissionStatus permissionStatus = AppPermissionStatus.denied,
      bool serviceEnabled = true,
      String? geoResult,
      Weather? weatherResult,
    }) {
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

      return _envScope(
        permissionStatus: permissionStatus,
        serviceEnabled: serviceEnabled,
        geoResult: geoResult,
        weatherResult: weatherResult,
        child: MaterialApp.router(
          routerConfig: testRouter,
          theme: KazeTheme.light(),
        ),
      );
    }

    testWidgets('问候语按注入时钟、三张入口卡齐备', (tester) async {
      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      expect(find.text('中午好'), findsOneWidget);
      expect(find.text('把此刻写下来，寄给远方'), findsWidgets);
      expect(find.text('随机漂流'), findsOneWidget);
      expect(find.text('就地发掘'), findsOneWidget);
      expect(find.text('写一封信'), findsOneWidget);
      // 环境行：时段芯片恒显示
      expect(find.text('昼'), findsOneWidget);
      // 降级时地点/天气芯片隐藏
      expect(find.text('北京市朝阳区'), findsNothing);
      expect(find.text('晴'), findsNothing);
    });

    testWidgets('三张卡各自导航', (tester) async {
      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

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

      expect(find.text('我的信'), findsOneWidget);
      expect(find.text('抄本'), findsOneWidget);
      expect(find.text('回信告知'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('关于风信'), findsOneWidget);

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings')), findsOneWidget);

      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关于风信'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('about')), findsOneWidget);
    });

    testWidgets('干净度守卫：无品牌角标、无抽屉底注、无连通性卡片', (tester) async {
      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      // AppBar 右上角无「风信」字样
      expect(find.text('风信'), findsNothing);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // 抽屉打开后品牌区恰一处；底部无 tagline 文本
      expect(find.text('风信'), findsOneWidget);
      expect(find.text('匿名 · 漂流 · 不追踪'), findsNothing);
      expect(find.textContaining('后端连通性'), findsNothing);
      // 左上角无关闭按钮
      expect(find.byIcon(Icons.close), findsNothing);
    });

    // ---- 新增：环境行三芯片 ----

    testWidgets('环境行降级时仅显示时段芯片', (tester) async {
      await tester.pumpWidget(
        pumpApp(permissionStatus: AppPermissionStatus.denied),
      );
      await tester.pumpAndSettle();

      expect(find.text('昼'), findsOneWidget);
      expect(find.text('北京市朝阳区'), findsNothing);
      expect(find.text('晴'), findsNothing);
    });

    testWidgets('环境行加载后显示地点+时段+天气三芯片', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          permissionStatus: AppPermissionStatus.granted,
          geoResult: '北京市朝阳区',
          weatherResult: const Weather(text: '晴'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('北京市朝阳区'), findsOneWidget);
      expect(find.text('昼'), findsOneWidget);
      expect(find.text('晴'), findsOneWidget);
      // 不显示温度
      expect(find.textContaining('°C'), findsNothing);
    });

    testWidgets('天气芯片仅显示描述文本，不含温度', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          permissionStatus: AppPermissionStatus.granted,
          geoResult: '北京市朝阳区',
          weatherResult: Weather(text: '多云', tempC: 18.5),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('多云'), findsOneWidget);
      expect(find.textContaining('18.5'), findsNothing);
      expect(find.textContaining('°C'), findsNothing);
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
