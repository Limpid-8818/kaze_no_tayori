/// 管理端会话存储（抽象 + 内存实现）。
///
/// typ=admin JWT 存 **sessionStorage**（标签页级，关页即失效）——
/// 比 localStorage 稳妥，后台工具的会话不该比登录窗口活得久。
/// package:web 不可在 VM 测试编译，平台实现经 `session_store.dart`
/// 的条件导出隔离；VM 测试一律用 [MemoryAdminSessionStore]。
library;

abstract class AdminSessionStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// 测试 / 非 Web 平台的内存假体。
class MemoryAdminSessionStore implements AdminSessionStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
