/// 应用权限的统一语义层。
///
/// feature 只依赖这里的类型，不直接依赖 permission_handler。
library;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as plugin;

enum AppPermission { location }

enum AppPermissionStatus {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

extension AppPermissionStatusX on AppPermissionStatus {
  bool get isGranted =>
      this == AppPermissionStatus.granted ||
      this == AppPermissionStatus.limited;

  bool get shouldOpenSettings =>
      this == AppPermissionStatus.permanentlyDenied ||
      this == AppPermissionStatus.restricted;
}

abstract interface class PermissionGateway {
  Future<AppPermissionStatus> check(AppPermission permission);

  Future<AppPermissionStatus> request(AppPermission permission);

  Future<bool> openSettings();
}

class PluginPermissionGateway implements PermissionGateway {
  const PluginPermissionGateway();

  @override
  Future<AppPermissionStatus> check(AppPermission permission) async {
    return _fromPlugin(await _toPlugin(permission).status);
  }

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    return _fromPlugin(await _toPlugin(permission).request());
  }

  @override
  Future<bool> openSettings() => plugin.openAppSettings();

  plugin.Permission _toPlugin(AppPermission permission) {
    return pluginPermissionFor(permission, isWeb: kIsWeb);
  }

  AppPermissionStatus _fromPlugin(plugin.PermissionStatus status) {
    return switch (status) {
      plugin.PermissionStatus.granted => AppPermissionStatus.granted,
      plugin.PermissionStatus.denied => AppPermissionStatus.denied,
      plugin.PermissionStatus.permanentlyDenied =>
        AppPermissionStatus.permanentlyDenied,
      plugin.PermissionStatus.restricted => AppPermissionStatus.restricted,
      plugin.PermissionStatus.limited => AppPermissionStatus.limited,
      plugin.PermissionStatus.provisional => AppPermissionStatus.limited,
    };
  }
}

@visibleForTesting
plugin.Permission pluginPermissionFor(
  AppPermission permission, {
  required bool isWeb,
}) {
  return switch (permission) {
    // permission_handler_html 只实现 location，不实现 locationWhenInUse；
    // 移动端仍只申请前台权限。
    AppPermission.location =>
      isWeb ? plugin.Permission.location : plugin.Permission.locationWhenInUse,
  };
}
