import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/controllers/location_controller.dart';
import 'package:kazenotayori/app/controllers/permission_controller.dart';
import 'package:kazenotayori/app/permissions/app_permission.dart';
import 'package:kazenotayori/data/device/location_gateway.dart';

class _FakePermissionGateway implements PermissionGateway {
  _FakePermissionGateway({required this.status, this.requestedStatus});

  AppPermissionStatus status;
  AppPermissionStatus? requestedStatus;
  var requestCount = 0;

  @override
  Future<AppPermissionStatus> check(AppPermission permission) async => status;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    requestCount += 1;
    status = requestedStatus ?? status;
    return status;
  }

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
      measuredAt: DateTime.utc(2026, 8, 25),
    );
  }
}

ProviderContainer _container(
  _FakePermissionGateway permissions,
  _FakeLocationGateway location,
) {
  return ProviderContainer(
    overrides: [
      permissionGatewayProvider.overrideWithValue(permissions),
      locationGatewayProvider.overrideWithValue(location),
    ],
  );
}

void main() {
  test('上下文未允许申请时，只检查权限，不弹系统申请', () async {
    final permissions = _FakePermissionGateway(
      status: AppPermissionStatus.denied,
    );
    final location = _FakeLocationGateway(serviceEnabled: true);
    final container = _container(permissions, location);
    addTearDown(container.dispose);

    await container
        .read(locationControllerProvider.notifier)
        .locate(requestPermission: false);

    expect(
      container.read(locationControllerProvider).phase,
      LocationPhase.permissionDenied,
    );
    expect(permissions.requestCount, 0);
    expect(location.currentCount, 0);
  });

  test('用户触发定位后申请权限，并写入可共享坐标', () async {
    final permissions = _FakePermissionGateway(
      status: AppPermissionStatus.denied,
      requestedStatus: AppPermissionStatus.granted,
    );
    final location = _FakeLocationGateway(serviceEnabled: true);
    final container = _container(permissions, location);
    addTearDown(container.dispose);

    await container
        .read(locationControllerProvider.notifier)
        .locate(requestPermission: true);

    final state = container.read(locationControllerProvider);
    expect(state.phase, LocationPhase.ready);
    expect(state.coordinate?.latitude, 24.4798);
    expect(permissions.requestCount, 1);
    expect(location.currentCount, 1);
  });

  test('服务关闭与永久拒绝是两个显式状态', () async {
    final serviceOffContainer = _container(
      _FakePermissionGateway(status: AppPermissionStatus.granted),
      _FakeLocationGateway(serviceEnabled: false),
    );
    addTearDown(serviceOffContainer.dispose);
    await serviceOffContainer
        .read(locationControllerProvider.notifier)
        .locate(requestPermission: true);
    expect(
      serviceOffContainer.read(locationControllerProvider).phase,
      LocationPhase.serviceDisabled,
    );

    final deniedContainer = _container(
      _FakePermissionGateway(status: AppPermissionStatus.permanentlyDenied),
      _FakeLocationGateway(serviceEnabled: true),
    );
    addTearDown(deniedContainer.dispose);
    await deniedContainer
        .read(locationControllerProvider.notifier)
        .locate(requestPermission: true);
    expect(
      deniedContainer.read(locationControllerProvider).phase,
      LocationPhase.permissionPermanentlyDenied,
    );
  });

  test('从未使用过定位时，回前台不会主动检查或申请', () async {
    final permissions = _FakePermissionGateway(
      status: AppPermissionStatus.denied,
    );
    final location = _FakeLocationGateway(serviceEnabled: true);
    final container = _container(permissions, location);
    addTearDown(container.dispose);

    await container.read(locationControllerProvider.notifier).refreshIfActive();

    expect(
      container.read(locationControllerProvider).phase,
      LocationPhase.idle,
    );
    expect(permissions.requestCount, 0);
    expect(location.currentCount, 0);
  });
}
