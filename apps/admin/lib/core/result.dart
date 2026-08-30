/// 统一的失败表达。
///
/// 与 apps/app `core/result.dart` 同源同款（跨 app 复制，非共享包）：
/// Dio、协议解析与后端错误先统一映射成 [ApiFailure]；feature controller
/// 再把它转成明确的降级状态。UI 不接触 DioException、TypeError 等底层异常。
library;

/// 后端统一错误体的 code（见 docs/API_CONTRACT.md）。
enum ApiErrorKind {
  network,
  unauthorized,
  notFound,
  validation,

  /// 可降级模块被刻意关闭 —— UI 应降级，不应报错。
  featureDisabled,

  /// 依赖暂不可达 —— 可提示稍后再试。
  serviceUnavailable,

  /// HTTP 成功，但响应形状与契约不一致。不得伪装为空列表。
  invalidResponse,

  /// 状态机表外流转 / 种子信守卫等业务冲突（409/403）。
  conflict,
  forbidden,
  unknown,
}

class ApiFailure implements Exception {
  const ApiFailure(this.kind, this.message, {this.code, this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final String? code;
  final int? statusCode;

  /// 是否属于「该降级而非报错」的情况（与 apps/app 同款）。
  bool get isDegradable =>
      kind == ApiErrorKind.featureDisabled ||
      kind == ApiErrorKind.serviceUnavailable;

  @override
  String toString() => 'ApiFailure($kind, $message)';
}
