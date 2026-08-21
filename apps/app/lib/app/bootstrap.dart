/// 冷启动引导：静默登录（F0）。
///
/// 任何失败都吞掉——token 缺失时后续首个请求 401，
/// ApiClient 的重绑拦截器会在网络恢复后自愈。离线也照常进 App。
library;

import '../data/api/api_client.dart';

/// 限时 6 秒：登录再重要也不能挡住首帧。
Future<void> ensureSession(ApiClient client) async {
  try {
    await client.ensureSession().timeout(const Duration(seconds: 6));
  } on Exception catch (_) {
    // 离线 / 后端未起 / 认证失败：静默放行，交给 401 重绑自愈。
  }
}
