/// 就地发掘页控制器 —— 定位 → 半径检索的编排者。
///
/// 定位统一消费全局 LocationController（ROADMAP F4）；拒绝分支只给
/// 「重试 / 去设置」，禁止默认坐标。列表不负责已读语义：点卡片进
/// 阅读器，markRead 恰一次由阅读器完成；读过的信下次检索自然消失
/// （服务端排除）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/device/location_gateway.dart';
import '../../app/controllers/location_controller.dart';
import '../../app/controllers/permission_controller.dart';
import 'discover_view.dart';

enum DiscoverPhase {
  locating,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  listLoading,

  /// ready 且 items 可能非空（空列表转 [DiscoverPhase.listEmpty]）。
  ready,
  listEmpty,
  error,
}

class DiscoverState {
  const DiscoverState({
    this.phase = DiscoverPhase.locating,
    this.items = const [],
  });

  final DiscoverPhase phase;
  final List<DiscoverLetterView> items;
}

final discoverControllerProvider =
    NotifierProvider<DiscoverController, DiscoverState>(DiscoverController.new);

class DiscoverController extends Notifier<DiscoverState> {
  @override
  DiscoverState build() => const DiscoverState();

  /// 进入页面 / 重试 / 下拉刷新统一入口。
  Future<void> start() async {
    state = const DiscoverState(phase: DiscoverPhase.locating);

    final location = ref.read(locationControllerProvider);
    if (location.phase != LocationPhase.ready) {
      await ref
          .read(locationControllerProvider.notifier)
          .locate(requestPermission: true);
      if (!ref.mounted) return;
    }
    switch (ref.read(locationControllerProvider).phase) {
      case LocationPhase.ready:
        break;
      case LocationPhase.serviceDisabled:
        state = const DiscoverState(phase: DiscoverPhase.serviceDisabled);
        return;
      case LocationPhase.permissionDenied:
        state = const DiscoverState(phase: DiscoverPhase.permissionDenied);
        return;
      case LocationPhase.permissionPermanentlyDenied:
        state = const DiscoverState(
          phase: DiscoverPhase.permissionPermanentlyDenied,
        );
        return;
      case LocationPhase.failed:
      case LocationPhase.idle:
      case LocationPhase.loading:
        state = const DiscoverState(phase: DiscoverPhase.error);
        return;
    }

    final coordinate = ref.read(locationControllerProvider).coordinate;
    if (coordinate == null) {
      state = const DiscoverState(phase: DiscoverPhase.error);
      return;
    }
    await _load(coordinate);
  }

  /// 下拉刷新 / 空态「刷新」按钮统一入口。
  ///
  /// 列表在场（ready）时不重建头部相位：列表留在原地，进度由
  /// RefreshIndicator 表达，失败且已有列表时保持原状。空态没有
  /// 指示器可借，切入 [DiscoverPhase.listLoading] 用翻找 spinner
  /// 表达进行中（同漂流页 draw 的相位法），失败转 error。
  Future<void> refresh() async {
    final coordinate = ref.read(locationControllerProvider).coordinate;
    if (coordinate == null) {
      await start();
      return;
    }
    if (state.phase == DiscoverPhase.listEmpty) {
      state = const DiscoverState(phase: DiscoverPhase.listLoading);
    }
    try {
      final page = await ref
          .read(discoverApiProvider)
          .list(
            lat: coordinate.latitude,
            lon: coordinate.longitude,
            radiusM: Env.discoverRadiusM,
            limit: 20,
          );
      if (!ref.mounted) return;
      final items = [
        for (final letter in page.items)
          DiscoverLetterView.from(
            letter,
            originLat: coordinate.latitude,
            originLon: coordinate.longitude,
          ),
      ];
      state = DiscoverState(
        phase: items.isEmpty ? DiscoverPhase.listEmpty : DiscoverPhase.ready,
        items: items,
      );
    } on ApiFailure {
      if (!ref.mounted) return;
      if (state.phase != DiscoverPhase.ready) {
        state = const DiscoverState(phase: DiscoverPhase.error);
      }
    }
  }

  /// 「去设置」后的归途：从系统设置回来重试整条链路
  /// （此时 check() 会拿到新权限，ready 则直接出列表）。
  Future<void> openSettingsThenRetry() async {
    await ref.read(permissionControllerProvider.notifier).openSettings();
    if (!ref.mounted) return;
    ref.read(permissionControllerProvider.notifier).refreshKnown();
    await start();
  }

  Future<void> _load(GeoCoordinate coordinate) async {
    state = const DiscoverState(phase: DiscoverPhase.listLoading);
    try {
      final page = await ref
          .read(discoverApiProvider)
          .list(
            lat: coordinate.latitude,
            lon: coordinate.longitude,
            radiusM: Env.discoverRadiusM,
            limit: 20,
          );
      if (!ref.mounted) return;
      final items = [
        for (final letter in page.items)
          DiscoverLetterView.from(
            letter,
            originLat: coordinate.latitude,
            originLon: coordinate.longitude,
          ),
      ];
      state = DiscoverState(
        phase: items.isEmpty ? DiscoverPhase.listEmpty : DiscoverPhase.ready,
        items: items,
      );
    } on ApiFailure {
      if (!ref.mounted) return;
      state = const DiscoverState(phase: DiscoverPhase.error);
    }
  }
}
