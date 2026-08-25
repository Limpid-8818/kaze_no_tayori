import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/controllers/permission_controller.dart';
import 'package:kazenotayori/app/permissions/app_permission.dart';

class _FakePermissionGateway implements PermissionGateway {
  _FakePermissionGateway({required this.checked, required this.requested});

  AppPermissionStatus checked;
  AppPermissionStatus requested;
  var requestCount = 0;
  var settingsCount = 0;

  @override
  Future<AppPermissionStatus> check(AppPermission permission) async => checked;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    requestCount += 1;
    return requested;
  }

  @override
  Future<bool> openSettings() async {
    settingsCount += 1;
    return true;
  }
}

void main() {
  test('检查、申请和设置跳转都更新同一份全局权限状态', () async {
    final gateway = _FakePermissionGateway(
      checked: AppPermissionStatus.denied,
      requested: AppPermissionStatus.granted,
    );
    final container = ProviderContainer(
      overrides: [permissionGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    final controller = container.read(permissionControllerProvider.notifier);
    expect(
      await controller.check(AppPermission.location),
      AppPermissionStatus.denied,
    );
    expect(
      container.read(permissionControllerProvider)[AppPermission.location],
      AppPermissionStatus.denied,
    );

    expect(
      await controller.request(AppPermission.location),
      AppPermissionStatus.granted,
    );
    expect(gateway.requestCount, 1);
    expect(
      container.read(permissionControllerProvider)[AppPermission.location],
      AppPermissionStatus.granted,
    );

    expect(await controller.openSettings(), isTrue);
    expect(gateway.settingsCount, 1);
  });
}
