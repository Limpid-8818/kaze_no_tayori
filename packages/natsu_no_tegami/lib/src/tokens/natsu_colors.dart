import 'dart:ui' show Color;

import 'package:flutter/painting.dart'
    show Alignment, LinearGradient;

/// 夏の手紙 v2 · 色彩令牌 — 「Summer Epistolary / 光在纸上」
///
/// 三层模型的色彩落地：
/// - 环境（天空=页面）：清透蓝渐变，夏日空气
/// - 纸面（内容表面）：纸只在「信」的时候出现——白纸浮于天空
/// - 墨（ink blue）：文字与主行动
/// - 点綴：skyBlue 交互主色、sunlightYellow 稀有高光、coralStamp 邮戳/旅行
///
/// 纪律：
/// - 大面积环境冷 + 纸面暖白的冷暖冲突本身就是夏天
/// - coralStamp 是配给色（邮戳/邮票/旅行标记，装饰图形不承载正文）
/// - sunlightYellow 永不作文字色（对比度不足，只做光）
abstract final class NatsuColors {
  // ---- 环境层（天空 = 页面）---------------------------------------------------
  /// 天空顶 — 清透天青（渐变上端）
  static const Color skyTop = Color(0xFFC9E2F2);

  /// 地平线 — 暖白（渐变下端；stops 0.72 让暖只占底部，防全页泛黄）
  static const Color skyHorizon = Color(0xFFFAF8F1);

  /// 阳光 — 纸面顶部高光 / 渐变端点
  static const Color sunlight = Color(0xFFFFF6DF);

  /// 叶绿 — 低频辅助（自然/旅行语义）
  static const Color leaf = Color(0xFF7FA88B);

  /// 页面天空渐变 — 垂直，天青 → 暖地平线
  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyHorizon],
    stops: [0.0, 0.72],
  );

  // ---- 纸面层（内容表面）-----------------------------------------------------
  /// 白纸 — 内容表面（信纸/照片白边）
  static const Color paperWhite = Color(0xFFFFFFFF);

  /// 封筒 — 暖白（引用底/禁用底；比环境更暖但依旧白）
  static const Color envelope = Color(0xFFFCF9F2);

  /// 纸缘 — 纸面描边
  static const Color paperEdge = Color(0xFFE8E4DA);

  // ---- 墨层（ink blue）-------------------------------------------------------
  /// 墨蓝 — 正文/标题/主按钮底
  static const Color inkBlue = Color(0xFF2B3A55);

  /// 次级墨 — 说明文字
  static const Color inkSoft = Color(0xFF55617D);

  /// 淡墨 — caption/meta（仅非关键小字）
  static const Color inkFaint = Color(0xFF8A93A8);

  // ---- 点綴层 -----------------------------------------------------------------
  /// 夏空蓝 — 交互主色（链接/选中/聚焦）
  static const Color skyBlue = Color(0xFF1F6FA8);

  /// 阳光黄 — 稀有高光（hover 光斑/情绪语义点；永不作文字色）
  static const Color sunlightYellow = Color(0xFFE8B84B);

  /// 珊瑚 — 邮戳/邮票/旅行标记（配给色，装饰图形）
  static const Color coralStamp = Color(0xFFE07A5F);

  // ---- 状态层 -----------------------------------------------------------------
  /// 悬停 — 墨蓝 4% 覆盖
  static const Color hoverOverlay = Color(0x0A2B3A55);

  /// 按压 — 墨蓝 8% 覆盖
  static const Color pressedOverlay = Color(0x142B3A55);

  /// 禁用内容 — 32% 透明
  static const Color disabledContent = Color(0x522B3A55);

  /// 聚焦环 — 夏空蓝
  static const Color focusRing = skyBlue;

  /// 遮罩 — 墨蓝 45%（浮纸之下的天空变暗；非文字对，不参与对比度仲裁）
  static const Color scrim = Color(0x732B3A55);

  /// 错误 — 唯一保留的 v1 朱值，仅错误语义
  static const Color error = Color(0xFFC0392B);

  /// 墨蓝底上的文字 — 阳光倾向的暖白（比纯白柔，比灰白亮）
  static const Color onInk = Color(0xFFFFFBF2);

  /// 珊瑚底上的文字 — 同暖白（深底一律亮字）
  static const Color onCoral = Color(0xFFFFFBF2);
}
