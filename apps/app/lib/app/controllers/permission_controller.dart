/// 全局权限控制器。
///
/// 它只维护权限状态与请求入口；申请前的用途说明由触发申请的页面负责。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../permissions/app_permission.dart';

final permissionGatewayProvider = Provider<PermissionGateway>(
  (_) => const PluginPermissionGateway(),
);

final permissionControllerProvider =
    NotifierProvider<
      PermissionController,
      Map<AppPermission, AppPermissionStatus>
    >(PermissionController.new);

class PermissionController
    extends Notifier<Map<AppPermission, AppPermissionStatus>> {
  @override
  Map<AppPermission, AppPermissionStatus> build() => const {};

  AppPermissionStatus statusOf(AppPermission permission) {
    return state[permission] ?? AppPermissionStatus.unknown;
  }

  Future<AppPermissionStatus> check(AppPermission permission) async {
    final status = await ref.read(permissionGatewayProvider).check(permission);
    _setStatus(permission, status);
    return status;
  }

  Future<AppPermissionStatus> request(AppPermission permission) async {
    final status = await ref
        .read(permissionGatewayProvider)
        .request(permission);
    _setStatus(permission, status);
    return status;
  }

  Future<bool> openSettings() {
    return ref.read(permissionGatewayProvider).openSettings();
  }

  Future<void> refreshKnown() async {
    for (final permission in state.keys.toList(growable: false)) {
      await check(permission);
    }
  }

  void _setStatus(AppPermission permission, AppPermissionStatus status) {
    state = {...state, permission: status};
  }
}
