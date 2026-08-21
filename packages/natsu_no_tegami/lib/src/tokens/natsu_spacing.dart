/// 夏の手紙 · 间距令牌 — 双刻度体系
///
/// 間（Ma / 余白）是本设计的核心层次手段（替代阴影）。两套刻度并存：
/// - [NatsuSpacingEditorial]：展示页容器尺度（Web 编辑排版，宽松）
/// - [NatsuSpacing]：组件内部尺度（移动端主体，紧凑）
/// - 组件专项（卡片/按钮/标签/输入框）单独具名。
abstract final class NatsuSpacing {
  // ---- 紧凑刻度（组件内部）---------------------------------------------------
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ---- 组件专项 --------------------------------------------------------------
  /// 卡片内边距
  static const double cardPadding = 28;

  /// 卡片内要素间
  static const double cardGap = 16;

  /// 按钮纵/横内边距
  static const double btnPaddingY = 12;
  static const double btnPaddingX = 24;

  /// 小按钮纵/横内边距
  static const double btnSmPaddingY = 8;
  static const double btnSmPaddingX = 16;

  /// 标签纵/横内边距
  static const double tagPaddingY = 8;
  static const double tagPaddingX = 16;

  /// 输入框高度
  static const double inputHeight = 48;

  /// 色板间距离
  static const double swatchGap = 24;

  // ---- 表单控件专项 ------------------------------------------------------------
  /// 开关轨道宽/高（药丸半径 = 高的一半，派生不设令牌）
  static const double switchTrackW = 36;
  static const double switchTrackH = 20;

  /// 开关旋钮直径
  static const double switchKnob = 14;

  /// 复选框边长
  static const double checkSize = 18;

  /// 单选环直径
  static const double radioSize = 20;

  /// 控件最小命中区（44px 触控标准）
  static const double controlHitTarget = 44;

  /// 滑块旋钮直径 / 轨道高
  static const double sliderKnob = 16;
  static const double sliderTrackH = 4;

  // ---- 反馈与浮层专项 ----------------------------------------------------------
  /// 进度条高度
  static const double progressH = 4;

  /// 加载指示 sm/md 直径
  static const double spinnerSm = 20;
  static const double spinnerMd = 28;

  /// 对话框最大宽
  static const double dialogMaxW = 400;

  /// 底部弹层最大宽
  static const double sheetMaxW = 640;

  /// 轻提示最大宽
  static const double toastMaxW = 480;

  /// 底部弹层拖拽把手宽/高
  static const double handleW = 36;
  static const double handleH = 4;
}

/// 编辑刻度 — 展示页/长文档容器专用
abstract final class NatsuSpacingEditorial {
  /// 页面左右余白
  static const double pagePadding = 120;

  /// 大章节之间的間（Ma）
  static const double sectionGap = 160;

  /// 章节内块间距
  static const double blockGap = 40;
}
