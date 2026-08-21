import 'package:flutter/painting.dart';

/// 夏の手紙 v2 · 阴影令牌 — 纸从天空浮起的深度线索
///
/// v2 模型里环境（天空）与纸面是两个物理平面：阴影是「纸被空气托起」的
/// 深度线索，不再禁用。影色统一墨蓝系（暖环境下冷影更「浮」），
/// 大 blur、低透明、向下偏移——极轻，只提示层次不制造重量。
///
/// 配给制：只用于纸面内容组件（Card/LetterPaper/PhotoCard/Stamp/Postmark）；
/// Button/Tag/Input 无阴影（它们是 UI 骨架，贴着结构层）。
abstract final class NatsuShadows {
  /// 纸面静置
  static const List<BoxShadow> paperResting = [
    BoxShadow(
      color: Color(0x1422436B),
      blurRadius: 24,
      spreadRadius: -8,
      offset: Offset(0, 6),
    ),
  ];

  /// 纸面被拈起（hover / 激活）
  static const List<BoxShadow> paperHover = [
    BoxShadow(
      color: Color(0x1F22436B),
      blurRadius: 32,
      spreadRadius: -10,
      offset: Offset(0, 10),
    ),
  ];

  /// 大纸面（信纸）— 更大更散
  static const List<BoxShadow> letterResting = [
    BoxShadow(
      color: Color(0x1422436B),
      blurRadius: 40,
      spreadRadius: -12,
      offset: Offset(0, 12),
    ),
  ];
}
