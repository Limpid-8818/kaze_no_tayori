/// 统一的失败表达。
///
/// 为什么不用异常穿透到 UI：可降级模块（AI / 天气 / 定位）失败时属于**预期路径**，
/// 界面该温和地退到手动模式，而不是弹一个红色报错。把「失败」变成值，
/// 就不容易在 UI 层漏掉降级分支。
library;

/// 后端统一错误体的 code（见 docs/API_CONTRACT.md）。
enum ApiErrorKind {
  network,
  unauthorized,
  notFound,
  validation,

  /// 可降级模块被刻意关闭 —— UI 应降级，不应报错。
  featureDisabled,

  /// 依赖暂不可达（如共享云库连不上）—— 可提示稍后再试。
  serviceUnavailable,

  /// 漂流池空了。这是叙事状态，不是错误：「暂时没有漂来的信」。
  driftPoolEmpty,
  unknown,
}

class ApiFailure implements Exception {
  const ApiFailure(this.kind, this.message, {this.code, this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final String? code;
  final int? statusCode;

  /// 是否属于「该降级而非报错」的情况。
  bool get isDegradable =>
      kind == ApiErrorKind.featureDisabled ||
      kind == ApiErrorKind.serviceUnavailable;

  @override
  String toString() => 'ApiFailure($kind, $message)';
}
