/// 认证端点（PRD 6.13）。
///
/// 设备绑定优先、无密码、全程无强制注册。
library;

import '../models/common.dart';
import 'api_client.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  /// 用 device_id 换长效 JWT。幂等：同一 device_id 重复调用返回同一用户。
  Future<TokenResponse> exchangeDevice(String deviceId) async {
    final json = await _client.postJson(
      '/v1/auth/device',
      body: {'device_id': deviceId},
    );
    return TokenResponse.fromJson(json);
  }
}
