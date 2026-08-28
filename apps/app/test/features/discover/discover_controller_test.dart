/// 发掘控制器测试：定位拒绝分支（无 API 调用）、就绪出列表、空列表、
/// 检索失败、俳句拆行与预览回退。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/controllers/location_controller.dart';
import 'package:kazenotayori/app/controllers/permission_controller.dart';
import 'package:kazenotayori/app/permissions/app_permission.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/data/device/location_gateway.dart';
import 'package:kazenotayori/features/discover/discover_controller.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

class _FakePermissionGateway implements PermissionGateway {
  _FakePermissionGateway(this.status);

  AppPermissionStatus status;

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
      measuredAt: DateTime.utc(2026, 8, 25),
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

DioException _server() => DioException(
  requestOptions: RequestOptions(path: '/v1/discover', baseUrl: 'http://test'),
  response: Response(
    requestOptions: RequestOptions(
      path: '/v1/discover',
      baseUrl: 'http://test',
    ),
    statusCode: 503,
    data: {
      'error': {'code': 'service_unavailable', 'message': 'x'},
    },
  ),
);

ProviderContainer _container(
  List<ScriptedResponse> script, {
  AppPermissionStatus permission = AppPermissionStatus.granted,
  bool serviceEnabled = true,
}) {
  final container = ProviderContainer(
    overrides: [
      permissionGatewayProvider.overrideWithValue(
        _FakePermissionGateway(permission),
      ),
      locationGatewayProvider.overrideWithValue(
        _FakeLocationGateway(serviceEnabled: serviceEnabled),
      ),
      apiClientProvider.overrideWithValue(
        ApiClient(
          dio: Dio(
            BaseOptions(
              baseUrl: 'http://test',
              contentType: Headers.jsonContentType,
            ),
          )..httpClientAdapter = ScriptedAdapter(script),
          store: fakeSecureStore(),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('权限被拒：停在解释态，一个网络请求都不发（空脚本不炸即证明）', () async {
    final c = _container([], permission: AppPermissionStatus.denied);

    await c.read(discoverControllerProvider.notifier).start();

    expect(
      c.read(discoverControllerProvider).phase,
      DiscoverPhase.permissionDenied,
    );
  });

  test('永久拒绝：显式态，引导去设置', () async {
    final c = _container([], permission: AppPermissionStatus.permanentlyDenied);

    await c.read(discoverControllerProvider.notifier).start();

    expect(
      c.read(discoverControllerProvider).phase,
      DiscoverPhase.permissionPermanentlyDenied,
    );
  });

  test('定位服务关闭：显式态而非错误', () async {
    final c = _container(
      [],
      permission: AppPermissionStatus.granted,
      serviceEnabled: false,
    );

    await c.read(discoverControllerProvider.notifier).start();

    expect(
      c.read(discoverControllerProvider).phase,
      DiscoverPhase.serviceDisabled,
    );
  });

  test('就绪：俳句拆行、预览文本、地点与相对时间各就各位', () async {
    final c = _container([
      ScriptedResponse.ok(200, {
        'items': [
          _stayJson(
            'stay_a',
            ago: const Duration(hours: 5),
            poem: '一行\n两行\n三行',
          ),
          _stayJson('stay_b', ago: const Duration(days: 3)),
        ],
        'next_cursor': null,
      }),
    ]);

    await c.read(discoverControllerProvider.notifier).start();

    final state = c.read(discoverControllerProvider);
    expect(state.phase, DiscoverPhase.ready);
    expect(state.items, hasLength(2));
    expect(state.items[0].poemLines, ['一行', '两行', '三行']);
    expect(state.items[1].poemLines, isEmpty);
    expect(state.items[1].previewText, contains('梧桐树叶间'));
    expect(state.items[0].timeLabel, '5小时前');
    expect(state.items[1].timeLabel, '3天前');
  });

  test('附近没信：叙事空态而非错误', () async {
    final c = _container([
      ScriptedResponse.ok(200, const {
        'items': <Object>[],
        'next_cursor': null,
      }),
    ]);

    await c.read(discoverControllerProvider.notifier).start();

    expect(c.read(discoverControllerProvider).phase, DiscoverPhase.listEmpty);
  });

  test('空态点刷新：先转翻找相位，仍为空则回到叙事空态', () async {
    final c = _container([
      ScriptedResponse.ok(200, const {
        'items': <Object>[],
        'next_cursor': null,
      }),
      ScriptedResponse.ok(200, const {
        'items': <Object>[],
        'next_cursor': null,
      }),
    ]);
    final notifier = c.read(discoverControllerProvider.notifier);

    await notifier.start();
    expect(c.read(discoverControllerProvider).phase, DiscoverPhase.listEmpty);

    final refreshing = notifier.refresh();
    expect(c.read(discoverControllerProvider).phase, DiscoverPhase.listLoading);
    await refreshing;
    expect(c.read(discoverControllerProvider).phase, DiscoverPhase.listEmpty);
  });

  test('空态刷新刷出信来：直接进 ready', () async {
    final c = _container([
      ScriptedResponse.ok(200, const {
        'items': <Object>[],
        'next_cursor': null,
      }),
      ScriptedResponse.ok(200, {
        'items': [_stayJson('stay_a', ago: const Duration(hours: 1))],
        'next_cursor': null,
      }),
    ]);
    final notifier = c.read(discoverControllerProvider.notifier);

    await notifier.start();
    await notifier.refresh();

    final state = c.read(discoverControllerProvider);
    expect(state.phase, DiscoverPhase.ready);
    expect(state.items, hasLength(1));
  });

  test('空态刷新失败：转 error 态', () async {
    final c = _container([
      ScriptedResponse.ok(200, const {
        'items': <Object>[],
        'next_cursor': null,
      }),
      ScriptedResponse.fail(_server()),
    ]);
    final notifier = c.read(discoverControllerProvider.notifier);

    await notifier.start();
    expect(c.read(discoverControllerProvider).phase, DiscoverPhase.listEmpty);

    await notifier.refresh();
    expect(c.read(discoverControllerProvider).phase, DiscoverPhase.error);
  });

  test('检索失败：error 态（重试入口在页面）', () async {
    final c = _container([
      ScriptedResponse.fail(_server()),
    ], permission: AppPermissionStatus.granted);

    await c.read(discoverControllerProvider.notifier).start();

    expect(c.read(discoverControllerProvider).phase, DiscoverPhase.error);
  });
}
