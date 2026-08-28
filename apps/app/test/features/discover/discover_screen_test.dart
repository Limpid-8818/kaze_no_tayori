/// 发掘页冒烟：定位卡+列表（俳句卡渲染）、点卡片进阅读器、拒绝态双按钮、
/// 空列表叙事。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kazenotayori/app/controllers/location_controller.dart';
import 'package:kazenotayori/app/controllers/permission_controller.dart';
import 'package:kazenotayori/app/permissions/app_permission.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/app/widgets/letter_summary_card.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/data/device/location_gateway.dart';
import 'package:kazenotayori/features/discover/discover_screen.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/frozen_home_environment.dart';
import '../../fakes/scripted_adapter.dart';

class _FakePermissionGateway implements PermissionGateway {
  _FakePermissionGateway(this.status);

  AppPermissionStatus status;
  var openSettingsCount = 0;

  @override
  Future<AppPermissionStatus> check(AppPermission permission) async => status;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async => status;

  @override
  Future<bool> openSettings() async {
    openSettingsCount += 1;
    return true;
  }
}

class _FakeLocationGateway implements LocationGateway {
  _FakeLocationGateway({required this.serviceEnabled});

  bool serviceEnabled;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<GeoCoordinate> current() async {
    return GeoCoordinate(
      latitude: 31.2,
      longitude: 121.4,
      accuracyM: 15,
      measuredAt: DateTime.now(),
    );
  }
}

Map<String, dynamic> _stayJson(
  String id, {
  required Duration ago,
  String? poem,
}) => {
  'id': id,
  'blocks': const [
    {'type': 'text', 'text': '风从梧桐树叶间穿过的时候，整条街都在轻轻摇晃。'},
  ],
  'poem': poem,
  'theme_id': 'natsu',
  'delivery_mode': 'stay',
  'place_label': '上海 · 武康路',
  'weather': const {'text': '多云', 'temp_c': 28.0},
  'parent_letter_id': null,
  'counts': const {
    'read': 0,
    'resonance': 0,
    'voice': 0,
    'reply': 0,
    'saved': 0,
  },
  'created_at': DateTime.now().subtract(ago).toIso8601String(),
};

// 环境链路（逆地理/天气）已被 frozenHomeEnvironmentOverride 冻结成静止替身
//（见 fakes/frozen_home_environment.dart），脚本只需覆盖 discover 列表本身。

class _Harness {
  _Harness({
    required List<ScriptedResponse> script,
    AppPermissionStatus permission = AppPermissionStatus.granted,
    bool serviceEnabled = true,
  }) : adapter = ScriptedAdapter(script),
       permissions = _FakePermissionGateway(permission),
       location = _FakeLocationGateway(serviceEnabled: serviceEnabled),
       pushed = <String>[];

  final ScriptedAdapter adapter;
  final _FakePermissionGateway permissions;
  final _FakeLocationGateway location;
  final List<String> pushed;

  Widget app() {
    final router = GoRouter(
      initialLocation: '/discover',
      routes: [
        GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
        GoRoute(
          path: '/letters/:id',
          builder: (_, state) {
            pushed.add(state.pathParameters['id']!);
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      overrides: [
        frozenHomeEnvironmentOverride,
        permissionGatewayProvider.overrideWithValue(permissions),
        locationGatewayProvider.overrideWithValue(location),
        apiClientProvider.overrideWithValue(
          ApiClient(
            dio: Dio(
              BaseOptions(
                baseUrl: 'http://test',
                contentType: Headers.jsonContentType,
              ),
            )..httpClientAdapter = adapter,
            store: fakeSecureStore(),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router, theme: KazeTheme.light()),
    );
  }
}

void main() {
  testWidgets('就绪：定位卡带半径与计数，俳句三行卡渲染，无诗卡走预览', (tester) async {
    final h = _Harness(
      script: [
        ScriptedResponse.ok(200, {
          'items': [
            _stayJson(
              'stay_a',
              ago: const Duration(hours: 5),
              poem: '风穿过堤岸\n把下午吹得很轻\n浪只说了一半',
            ),
            _stayJson('stay_b', ago: const Duration(days: 3)),
          ],
          'next_cursor': null,
        }),
      ],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('半径 1km · 找到 2 封信'), findsOneWidget);
    expect(find.text('风穿过堤岸'), findsOneWidget);
    expect(find.text('浪只说了一半'), findsOneWidget);
    // 无诗信预览
    expect(find.text('风从梧桐树叶间穿过的时候，整条街都在轻轻摇晃。'), findsOneWidget);
  });

  testWidgets('点卡片：push 对应阅读器路由（拆封语义归阅读器）', (tester) async {
    final h = _Harness(
      script: [
        ScriptedResponse.ok(200, {
          'items': [_stayJson('stay_a', ago: const Duration(hours: 5))],
          'next_cursor': null,
        }),
      ],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('梧桐树叶间'));
    await tester.pumpAndSettle();

    expect(h.pushed, ['stay_a']);
  });

  testWidgets('权限被拒：解释 + 去设置 / 再试一次 双动作，不出列表', (tester) async {
    final h = _Harness(script: [], permission: AppPermissionStatus.denied);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('没有拿到定位权限'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);
    expect(find.text('再试一次'), findsOneWidget);
    expect(find.byType(LetterSummaryCard), findsNothing);
  });

  testWidgets('附近没信：叙事空态', (tester) async {
    final h = _Harness(
      script: [
        ScriptedResponse.ok(200, const {
          'items': <Object>[],
          'next_cursor': null,
        }),
      ],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('附近还没有埋下的信'), findsOneWidget);
  });

  testWidgets('空态点刷新：经翻找 spinner 回到空态，可再次刷新', (tester) async {
    final h = _Harness(
      script: [
        ScriptedResponse.ok(200, const {
          'items': <Object>[],
          'next_cursor': null,
        }),
        ScriptedResponse.ok(200, const {
          'items': <Object>[],
          'next_cursor': null,
        }),
        ScriptedResponse.ok(200, const {
          'items': <Object>[],
          'next_cursor': null,
        }),
      ],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('附近还没有埋下的信'), findsOneWidget);

    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();
    expect(find.text('附近还没有埋下的信'), findsOneWidget);

    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();
    expect(find.text('附近还没有埋下的信'), findsOneWidget);
    expect(h.adapter.requests, hasLength(3));
  });
}
