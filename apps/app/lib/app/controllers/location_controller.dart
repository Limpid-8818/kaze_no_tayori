/// 全局定位状态：写信落点、首页环境和就地发掘共用同一份坐标。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/device/location_gateway.dart';
import '../permissions/app_permission.dart';
import 'permission_controller.dart';

enum LocationPhase {
  idle,
  loading,
  ready,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  failed,
}

class AppLocationState {
  const AppLocationState({
    this.phase = LocationPhase.idle,
    this.coordinate,
    this.error,
  });

  final LocationPhase phase;
  final GeoCoordinate? coordinate;
  final Object? error;

  bool get hasRequested => phase != LocationPhase.idle;
}

final locationGatewayProvider = Provider<LocationGateway>(
  (_) => const GeolocatorLocationGateway(),
);

final locationControllerProvider =
    NotifierProvider<LocationController, AppLocationState>(
      LocationController.new,
    );

class LocationController extends Notifier<AppLocationState> {
  @override
  AppLocationState build() => const AppLocationState();

  /// 获取当前位置。只有用户在需要位置的场景明确触发时，才传 requestPermission=true。
  Future<void> locate({required bool requestPermission}) async {
    await _locate(requestPermission: requestPermission, checkPermission: true);
  }

  Future<void> _locate({
    required bool requestPermission,
    required bool checkPermission,
  }) async {
    if (state.phase == LocationPhase.loading) return;

    state = AppLocationState(
      phase: LocationPhase.loading,
      coordinate: state.coordinate,
    );

    try {
      final serviceEnabled = await ref
          .read(locationGatewayProvider)
          .isServiceEnabled();
      if (!serviceEnabled) {
        state = AppLocationState(
          phase: LocationPhase.serviceDisabled,
          coordinate: state.coordinate,
        );
        return;
      }

      final permissions = ref.read(permissionControllerProvider.notifier);
      var permission = checkPermission
          ? await permissions.check(AppPermission.location)
          : permissions.statusOf(AppPermission.location);
      if (!permission.isGranted &&
          requestPermission &&
          !permission.shouldOpenSettings) {
        permission = await permissions.request(AppPermission.location);
      }

      if (!permission.isGranted) {
        state = AppLocationState(
          phase: permission.shouldOpenSettings
              ? LocationPhase.permissionPermanentlyDenied
              : LocationPhase.permissionDenied,
          coordinate: state.coordinate,
        );
        return;
      }

      final coordinate = await ref.read(locationGatewayProvider).current();
      state = AppLocationState(
        phase: LocationPhase.ready,
        coordinate: coordinate,
      );
    } on Object catch (error) {
      state = AppLocationState(
        phase: LocationPhase.failed,
        coordinate: state.coordinate,
        error: error,
      );
    }
  }

  /// 回到前台时只刷新已经使用过的定位，不在冷启动阶段突然申请权限。
  Future<void> refreshIfActive({bool permissionIsFresh = false}) async {
    if (!state.hasRequested) return;
    await _locate(
      requestPermission: false,
      checkPermission: !permissionIsFresh,
    );
  }
}
