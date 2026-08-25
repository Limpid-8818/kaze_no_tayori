/// 首帧后的会话预热（F0）。
///
/// 任何失败都吞掉——token 缺失时后续首个请求 401，
/// ApiClient 的重绑拦截器会在网络恢复后自愈。离线也照常进 App。
library;

import '../data/api/api_client.dart';

/// 限时 6 秒；调用方必须 fire-and-forget，不得把它放在 runApp 前 await。
Future<void> ensureSession(ApiClient client) async {
  try {
    await client.ensureSession().timeout(const Duration(seconds: 6));
  } on Exception catch (_) {
    // 离线 / 后端未起 / 认证失败：静默放行，交给 401 重绑自愈。
  }
}
