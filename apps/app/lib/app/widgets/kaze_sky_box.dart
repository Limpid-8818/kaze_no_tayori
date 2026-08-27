/// 动画天空容器 —— 天色联动的渲染端。
///
/// watch [skyControllerProvider]，档位变化时以 drift 曲线对渐变端点
/// 插值（画廊 ShowcaseShell 同款隐式动画方案；两端都是令牌层 const
/// 预设，lerp 只发生在 widget 层）。传入 [gradient] 后不再跟随全局
/// —— 读信页锁定信件携带的天色专用。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/sky_controller.dart';
import '../theme.dart';

class KazeSkyBox extends ConsumerWidget {
  const KazeSkyBox({required this.child, this.gradient, super.key});

  final Widget child;

  /// 覆盖渐变 —— 非空时不吃全局天色（读信页信件驱动）。
  final Gradient? gradient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effective = gradient ?? ref.watch(skyControllerProvider).gradient;
    return AnimatedContainer(
      duration: KazeMotion.drift,
      curve: KazeMotion.driftEasing,
      decoration: BoxDecoration(gradient: effective),
      child: child,
    );
  }
}
