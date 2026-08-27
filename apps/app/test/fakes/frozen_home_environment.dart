/// 页面级 widget 测试的「静止环境」替身。
///
/// 真实 [homeEnvironmentControllerProvider] 的 build 会经 microtask 触发
/// 定位（冷启动 locate）并随后拉逆地理/天气——页面冒烟测试不需要这条
/// 副作用链，统一 override 成恒空状态：天色联动稳定落到「时段·晴」，
/// 测试脚本也不必为环境请求预留顺序。
library;

import 'package:kazenotayori/app/controllers/home_environment_controller.dart';

class FrozenHomeEnvironmentController extends HomeEnvironmentController {
  @override
  HomeEnvironmentState build() => const HomeEnvironmentState();
}

final frozenHomeEnvironmentOverride = homeEnvironmentControllerProvider
    .overrideWith(FrozenHomeEnvironmentController.new);
