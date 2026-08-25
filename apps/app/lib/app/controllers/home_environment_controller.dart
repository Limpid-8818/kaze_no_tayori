/// 首页环境信息控制器：整合全局定位 + 逆地理 + 天气，供给环境行消费。
///
/// 降级纪律：Geo / Weather 均为可降级模块，失败时静默返回 null，
/// UI 不展示对应芯片，不阻断 App 启动。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/providers.dart';
import '../../data/device/location_gateway.dart';
import '../../data/models/letter.dart';
import '../../core/result.dart';
import '../controllers/location_controller.dart';

/// 首页环境信息状态。
class HomeEnvironmentState {
  const HomeEnvironmentState({
    this.coordinate,
    this.placeLabel,
    this.weather,
    this.envLoading = false,
  });

  final GeoCoordinate? coordinate;
  final String? placeLabel;
  final Weather? weather;
  final bool envLoading;

  bool get hasCoordinate => coordinate != null;
}

final homeEnvironmentControllerProvider =
    NotifierProvider<HomeEnvironmentController, HomeEnvironmentState>(
      HomeEnvironmentController.new,
    );

class HomeEnvironmentController extends Notifier<HomeEnvironmentState> {
  @override
  HomeEnvironmentState build() {
    Future.microtask(() {
      _setupListener();
      _checkInitialLocation();
    });
    return const HomeEnvironmentState();
  }

  void _setupListener() {
    ref.listen<AppLocationState>(locationControllerProvider, (previous, next) {
      if (previous == null) return;
      final wasReady = previous.phase == LocationPhase.ready;
      final isReady = next.phase == LocationPhase.ready;
      if (!wasReady && isReady && next.coordinate != null) {
        _fetchEnv(next.coordinate!);
      }
      if (wasReady &&
          isReady &&
          next.coordinate != null &&
          !identical(next.coordinate, previous.coordinate)) {
        _fetchEnv(next.coordinate!);
      }
    });
  }

  void _checkInitialLocation() {
    final initialLocation = ref.read(locationControllerProvider);
    if (initialLocation.phase == LocationPhase.ready &&
        initialLocation.coordinate != null) {
      _fetchEnv(initialLocation.coordinate!);
    }
    if (initialLocation.phase == LocationPhase.idle) {
      ref
          .read(locationControllerProvider.notifier)
          .locate(requestPermission: true);
    }
  }

  Future<void> _fetchEnv(GeoCoordinate coordinate) async {
    if (state.envLoading) return;
    if (identical(state.coordinate, coordinate)) return;

    state = HomeEnvironmentState(
      coordinate: state.coordinate,
      placeLabel: null,
      weather: null,
      envLoading: true,
    );

    try {
      final results = await Future.wait<dynamic>([
        ref
            .read(geoApiProvider)
            .reverse(coordinate.latitude, coordinate.longitude),
        ref
            .read(weatherApiProvider)
            .getCurrentWeather(coordinate.latitude, coordinate.longitude),
      ]);

      state = HomeEnvironmentState(
        coordinate: coordinate,
        placeLabel: results[0] as String?,
        weather: results[1] as Weather?,
        envLoading: false,
      );
    } on ApiFailure catch (_) {
      state = HomeEnvironmentState(
        coordinate: coordinate,
        placeLabel: null,
        weather: null,
        envLoading: false,
      );
    } on Object catch (_) {
      state = HomeEnvironmentState(
        coordinate: coordinate,
        placeLabel: null,
        weather: null,
        envLoading: false,
      );
    }
  }
}
