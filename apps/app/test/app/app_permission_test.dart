import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/permissions/app_permission.dart';
import 'package:permission_handler/permission_handler.dart' as plugin;

void main() {
  test('Web 与移动端使用各自实际支持的前台定位权限', () {
    expect(
      pluginPermissionFor(AppPermission.location, isWeb: true),
      plugin.Permission.location,
    );
    expect(
      pluginPermissionFor(AppPermission.location, isWeb: false),
      plugin.Permission.locationWhenInUse,
    );
  });
}
