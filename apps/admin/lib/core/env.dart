/// 运行时配置，由 `--dart-define` 注入。
///
/// 控制台跑在本机浏览器上，默认 localhost 即可：
///   make admin   # flutter run -d edge（Windows 无 Chrome，见根 CLAUDE.md）
library;

abstract final class Env {
  /// 后端地址。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// 列表默认分页上限（契约 ≤50）。
  static const int pageSize = 50;
}
