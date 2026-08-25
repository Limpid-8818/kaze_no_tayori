/// 首页环境信息控制器测试。
///
/// 覆盖：坐标就绪后并行请求 Geo + Weather、Geo 降级、Weather 降级、
/// 坐标变化时重新拉取、定位状态机各阶段不误触发。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kazenotayori/app/controllers/home_environment_controller.dart';
import 'package:kazenotayori/app/controllers/location_controller.dart';
import 'package:kazenotayori/app/controllers/permission_controller.dart';
import 'package:kazenotayori/app/permissions/app_permission.dart';
import 'package:kazenotayori/core/result.dart';
import 'package:kazenotayori/data/api/geo_api.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/data/api/weather_api.dart';
import 'package:kazenotayori/data/device/location_gateway.dart';
import 'package:kazenotayori/data/models/letter.dart';

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
  var currentCount = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<GeoCoordinate> current() async {
    currentCount += 1;
    return GeoCoordinate(
      latitude: 24.4798,
      longitude: 118.0894,
      accuracyM: 12,
      measuredAt: DateTime(2026, 8, 25),
    );
  }
}

class _FakeWeatherApi implements WeatherApi {
  _FakeWeatherApi({this.result, this.error});

  final Weather? result;
  final ApiFailure? error;

  var callCount = 0;

  @override
  Future<Weather?> getCurrentWeather(double lat, double lon) async {
    callCount += 1;
    if (error != null) throw error!;
    return result;
  }
}

class _FakeGeoApi implements GeoApi {
  _FakeGeoApi({this.result, this.error});

  final String? result;
  final ApiFailure? error;

  var callCount = 0;

  @override
  Future<String?> reverse(double lat, double lon) async {
    callCount += 1;
    if (error != null) throw error!;
    return result;
  }
}

// ---- 容器工厂 ----

ProviderContainer _container({
  required AppPermissionStatus permissionStatus,
  required bool serviceEnabled,
  required Weather? weatherResult,
  required ApiFailure? weatherError,
  required String? geoResult,
  required ApiFailure? geoError,
}) {
  final permissions = _FakePermissionGateway(status: permissionStatus);
  final location = _FakeLocationGateway(serviceEnabled: serviceEnabled);
  final weatherApi = _FakeWeatherApi(
    result: weatherResult,
    error: weatherError,
  );
  final geoApi = _FakeGeoApi(result: geoResult, error: geoError);

  return ProviderContainer(
    overrides: [
      permissionGatewayProvider.overrideWithValue(permissions),
      locationGatewayProvider.overrideWithValue(location),
      weatherApiProvider.overrideWithValue(weatherApi),
      geoApiProvider.overrideWithValue(geoApi),
    ],
  );
}

// ---- 辅助 ----

final _testCoordinate = GeoCoordinate(
  latitude: 24.4798,
  longitude: 118.0894,
  accuracyM: 12,
  measuredAt: DateTime(2026, 8, 25),
);

const _testWeather = Weather(text: '晴');
const _testPlaceLabel = '北京市朝阳区';

void _setLocationReady(ProviderContainer container) {
  final locationController = container.read(
    locationControllerProvider.notifier,
  );
  locationController.state = AppLocationState(
    phase: LocationPhase.ready,
    coordinate: _testCoordinate,
  );
}

/// 等待所有待处理的微任务完成（包括 _watchLocation 和 _fetchEnv）。
Future<void> _pumpMicrotasks() async {
  await Future.microtask(() {});
  await Future.microtask(() {});
  await Future.microtask(() {});
}

// ---- 测试 ----

void main() {
  group('HomeEnvironmentController', () {
    test('定位 ready 后并行请求 Geo + Weather', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.granted,
        serviceEnabled: true,
        weatherResult: _testWeather,
        weatherError: null,
        geoResult: _testPlaceLabel,
        geoError: null,
      );
      addTearDown(container.dispose);

      // 启动时触发 build()，_watchLocation 通过 Future.microtask 延迟执行
      container.read(homeEnvironmentControllerProvider);

      // 坐标就绪 → 触发 Geo + Weather
      _setLocationReady(container);

      // 等待 microtask 队列清空（_watchLocation 设置 listener → _fetchEnv 完成）
      await _pumpMicrotasks();

      final envState = container.read(homeEnvironmentControllerProvider);
      expect(envState.coordinate?.latitude, _testCoordinate.latitude);
      expect(envState.coordinate?.longitude, _testCoordinate.longitude);
      expect(envState.placeLabel, _testPlaceLabel);
      expect(envState.weather?.text, '晴');
      expect(envState.envLoading, false);
    });

    test('Geo API 降级：placeLabel 为 null，weather 正常', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.granted,
        serviceEnabled: true,
        weatherResult: _testWeather,
        weatherError: null,
        geoResult: null,
        geoError: null,
      );
      addTearDown(container.dispose);

      container.read(homeEnvironmentControllerProvider);
      _setLocationReady(container);
      await _pumpMicrotasks();

      final envState = container.read(homeEnvironmentControllerProvider);
      expect(envState.coordinate?.latitude, _testCoordinate.latitude);
      expect(envState.placeLabel, isNull);
      expect(envState.weather?.text, '晴');
    });

    test('Weather API 降级：weather 为 null，placeLabel 正常', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.granted,
        serviceEnabled: true,
        weatherResult: null,
        weatherError: null,
        geoResult: _testPlaceLabel,
        geoError: null,
      );
      addTearDown(container.dispose);

      container.read(homeEnvironmentControllerProvider);
      _setLocationReady(container);
      await _pumpMicrotasks();

      final envState = container.read(homeEnvironmentControllerProvider);
      expect(envState.coordinate?.latitude, _testCoordinate.latitude);
      expect(envState.placeLabel, _testPlaceLabel);
      expect(envState.weather, isNull);
    });

    test('Geo + Weather 均降级：仅保留 coordinate', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.granted,
        serviceEnabled: true,
        weatherResult: null,
        weatherError: null,
        geoResult: null,
        geoError: null,
      );
      addTearDown(container.dispose);

      container.read(homeEnvironmentControllerProvider);
      _setLocationReady(container);
      await _pumpMicrotasks();

      final envState = container.read(homeEnvironmentControllerProvider);
      expect(envState.coordinate?.latitude, _testCoordinate.latitude);
      expect(envState.placeLabel, isNull);
      expect(envState.weather, isNull);
    });

    test('坐标变化时重新拉取 Geo + Weather', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.granted,
        serviceEnabled: true,
        weatherResult: _testWeather,
        weatherError: null,
        geoResult: _testPlaceLabel,
        geoError: null,
      );
      addTearDown(container.dispose);

      // 首次 ready
      container.read(homeEnvironmentControllerProvider);
      _setLocationReady(container);
      await _pumpMicrotasks();

      final weatherApi = container.read(weatherApiProvider) as _FakeWeatherApi;
      final geoApi = container.read(geoApiProvider) as _FakeGeoApi;

      expect(weatherApi.callCount, 1);
      expect(geoApi.callCount, 1);

      // 模拟坐标刷新（回前台 refreshIfActive 后坐标变化）
      final newCoordinate = GeoCoordinate(
        latitude: 35.6762,
        longitude: 139.6503,
        accuracyM: 20,
        measuredAt: DateTime(2026, 8, 25, 8),
      );
      container
          .read(locationControllerProvider.notifier)
          .state = AppLocationState(
        phase: LocationPhase.ready,
        coordinate: newCoordinate,
      );

      await _pumpMicrotasks();

      expect(weatherApi.callCount, 2);
      expect(geoApi.callCount, 2);

      final envState = container.read(homeEnvironmentControllerProvider);
      expect(envState.coordinate?.latitude, newCoordinate.latitude);
      expect(envState.coordinate?.longitude, newCoordinate.longitude);
    });

    test('坐标未变化时不重复拉取', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.granted,
        serviceEnabled: true,
        weatherResult: _testWeather,
        weatherError: null,
        geoResult: _testPlaceLabel,
        geoError: null,
      );
      addTearDown(container.dispose);

      container.read(homeEnvironmentControllerProvider);
      _setLocationReady(container);
      await _pumpMicrotasks();

      final weatherApi = container.read(weatherApiProvider) as _FakeWeatherApi;
      final geoApi = container.read(geoApiProvider) as _FakeGeoApi;
      expect(weatherApi.callCount, 1);
      expect(geoApi.callCount, 1);

      // 同一坐标再次 ready（refreshIfActive 返回相同坐标）
      container
          .read(locationControllerProvider.notifier)
          .state = AppLocationState(
        phase: LocationPhase.ready,
        coordinate: _testCoordinate,
      );

      await _pumpMicrotasks();

      expect(weatherApi.callCount, 1); // 不增加
      expect(geoApi.callCount, 1); // 不增加
    });

    test('定位非 ready 状态不触发 Geo + Weather 请求', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.denied,
        serviceEnabled: true,
        weatherResult: null,
        weatherError: null,
        geoResult: null,
        geoError: null,
      );
      addTearDown(container.dispose);

      // 定位失败 → 不会触发环境拉取
      container.read(locationControllerProvider.notifier).state =
          const AppLocationState(phase: LocationPhase.permissionDenied);

      container.read(homeEnvironmentControllerProvider);
      await _pumpMicrotasks();

      final weatherApi = container.read(weatherApiProvider) as _FakeWeatherApi;
      final geoApi = container.read(geoApiProvider) as _FakeGeoApi;
      expect(weatherApi.callCount, 0);
      expect(geoApi.callCount, 0);
    });

    test('serviceDisabled / permissionDenied 均不触发环境拉取', () async {
      for (final phase in const [
        LocationPhase.serviceDisabled,
        LocationPhase.permissionDenied,
        LocationPhase.permissionPermanentlyDenied,
        LocationPhase.failed,
      ]) {
        final container = _container(
          permissionStatus: AppPermissionStatus.granted,
          serviceEnabled: true,
          weatherResult: null,
          weatherError: null,
          geoResult: null,
          geoError: null,
        );
        addTearDown(container.dispose);

        container.read(locationControllerProvider.notifier).state =
            AppLocationState(phase: phase);

        container.read(homeEnvironmentControllerProvider);
        await _pumpMicrotasks();

        final weatherApi =
            container.read(weatherApiProvider) as _FakeWeatherApi;
        final geoApi = container.read(geoApiProvider) as _FakeGeoApi;
        expect(
          weatherApi.callCount,
          0,
          reason: 'phase $phase should not trigger weather',
        );
        expect(
          geoApi.callCount,
          0,
          reason: 'phase $phase should not trigger geo',
        );
      }
    });

    test('启动时定位已是 ready，立即拉取环境信息', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.granted,
        serviceEnabled: true,
        weatherResult: _testWeather,
        weatherError: null,
        geoResult: _testPlaceLabel,
        geoError: null,
      );
      addTearDown(container.dispose);

      // 预先将定位设为 ready（模拟热重载/状态保留）
      container
          .read(locationControllerProvider.notifier)
          .state = AppLocationState(
        phase: LocationPhase.ready,
        coordinate: _testCoordinate,
      );

      // 创建控制器：build() 应检测到初始 ready 并立即拉取
      container.read(homeEnvironmentControllerProvider);

      await _pumpMicrotasks();

      final envState = container.read(homeEnvironmentControllerProvider);
      expect(envState.coordinate?.latitude, _testCoordinate.latitude);
      expect(envState.placeLabel, _testPlaceLabel);
      expect(envState.weather?.text, '晴');
    });

    test('ApiFailure 降级：异常不阻断，coordinate 保留', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.granted,
        serviceEnabled: true,
        weatherResult: null,
        weatherError: const ApiFailure(
          ApiErrorKind.serviceUnavailable,
          '服务不可用',
        ),
        geoResult: null,
        geoError: const ApiFailure(ApiErrorKind.featureDisabled, '功能关闭'),
      );
      addTearDown(container.dispose);

      container.read(homeEnvironmentControllerProvider);
      _setLocationReady(container);
      await _pumpMicrotasks();

      final envState = container.read(homeEnvironmentControllerProvider);
      expect(envState.coordinate?.latitude, _testCoordinate.latitude);
      expect(envState.placeLabel, isNull);
      expect(envState.weather, isNull);
      expect(envState.envLoading, false);
    });

    test('启动时 idle 状态触发 locate(requestPermission: true)', () async {
      final container = _container(
        permissionStatus: AppPermissionStatus.granted,
        serviceEnabled: true,
        weatherResult: _testWeather,
        weatherError: null,
        geoResult: _testPlaceLabel,
        geoError: null,
      );
      addTearDown(container.dispose);

      final locationController = container.read(
        locationControllerProvider.notifier,
      );
      // 此时还是 idle
      expect(locationController.state.phase, LocationPhase.idle);

      // 创建控制器：应触发 locate
      container.read(homeEnvironmentControllerProvider.notifier);

      // 等待 locate 完成（locate 内部有多次 microtask：isServiceEnabled、check、request、current）
      await _pumpMicrotasks();
      await _pumpMicrotasks();

      expect(locationController.state.phase, LocationPhase.ready);
      expect(locationController.state.coordinate, isNotNull);
    });
  });
}
