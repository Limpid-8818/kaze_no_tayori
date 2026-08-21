/// device_id 与 JWT 的本地存储（PRD 6.13 设备绑定）。
///
/// device_id 是客户端生成的 UUIDv4，是「无强制注册」的基石：
/// 用它换一个长效 JWT，用户全程不需要填任何东西。
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _kDeviceId = 'kaze.device_id';
  static const _kToken = 'kaze.access_token';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<void> writeToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<String?> readDeviceId() => _storage.read(key: _kDeviceId);

  Future<void> writeDeviceId(String id) =>
      _storage.write(key: _kDeviceId, value: id);

  /// 读出或生成 device_id（UUIDv4，36 字符，落在后端 8–64 约束内）。
  /// 首启后保证非空且稳定——「无强制注册」的基石。
  Future<String> ensureDeviceId() async {
    final existing = await _storage.read(key: _kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: _kDeviceId, value: id);
    return id;
  }

  /// 清空本地身份。用于「删除我的数据」（PRD §8.1 可删除）。
  Future<void> clear() => _storage.deleteAll();
}
