/// 运行时配置，由 `--dart-define` 注入。
///
/// 真机调试时 API_BASE_URL 不能用 localhost（那是手机自己），要用电脑的局域网 IP：
///   make app-android API_BASE_URL=http://192.168.x.x:8000
library;

abstract final class Env {
  /// 后端地址。默认值只对 Web/桌面调试有效。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// 就地发掘的默认半径（米）。服务端也有默认值，此处仅用于 UI 预设。
  static const int discoverRadiusM = int.fromEnvironment(
    'DISCOVER_RADIUS_M',
    defaultValue: 1000,
  );

  /// 运行时 mock 开关：true 时全部网络走本地 [MockApiAdapter]
  /// （data/api/mock/），不起后端也能走通写信闭环。
  /// `make app-android-emulator-mock`。
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  /// debug 天色强制档（验收/演示用）：12 键 camelCase，如 nightRainy /
  /// duskCloudy，见 KazeSky.parseForce。仅 debug 构建生效；非法值忽略，
  /// 生产构建不传即恒空。
  static const String skyForce = String.fromEnvironment('SKY_FORCE');

  /// 产品要求的整封正文上限（PRD 6.1）。
  static const int letterMaxChars = 800;

  /// 协议对单个文字块的防御性上限。当前与整封上限相同，但语义不同。
  static const int textBlockMaxChars = 800;

  static const int letterMaxBlocks = 20;

  static const int photoNoteMaxChars = 200;

  static const int letterMaxTags = 3;

  static const int signatureMaxChars = 32;

  static const int addresseeMaxChars = 32;

  static const int placeLabelMaxChars = 128;

  static const int musicNameMaxChars = 128;

  static const int musicLyricsMaxChars = 200;

  /// 附图上限（明信片式，1 张为主）。
  static const int letterMaxImages = 3;
}
