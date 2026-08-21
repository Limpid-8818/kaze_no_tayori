import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import 'natsu_colors.dart';

/// 夏の手紙 v2 · 圆角令牌
///
/// UI 骨架中等圆角（纸浮起后稍柔），信纸近直角（纸的裁切边）。
abstract final class NatsuRadius {
  /// 卡片·按钮·输入框
  static const double card = 6;

  /// 信纸（近直角）
  static const double letter = 2;

  /// 标签药丸
  static const double tag = 16;

  /// 小标签
  static const double tagSm = 14;

  /// 印枠（刻印外框）
  static const double stamp = 2;
}

/// 夏の手紙 v2 · 边框令牌
///
/// 层次的主力从「线」移交给「阴影 + 纸色差」；线只做纸缘提示。
abstract final class NatsuBorders {
  /// 纸缘线 — 卡片·标签
  static const Border hairline = Border.fromBorderSide(side);

  /// 纸缘 side
  static const BorderSide side =
      BorderSide(color: NatsuColors.paperEdge, width: 1);

  /// 输入线（稍深）
  static const BorderSide inputSide =
      BorderSide(color: Color(0xFFD5D0C4), width: 1);
}

/// 夏の手紙 v2 · 动效令牌 — 风、纸、光、漂流
///
/// 隐喻映射：
/// - short = 指尖按压 / hover 光
/// - medium = 纸被拈起（阴影 resting→hover）
/// - long = 纸落桌（卡片入场：offset(0,-12) + 种子 tilt → 静置）
/// - drift = 漂流到位（信件抵达 / 首屏落桌）——风送来的，比落桌更飘
abstract final class NatsuMotion {
  /// 短 — 按压反馈、hover 色变
  static const Duration short = Duration(milliseconds: 120);

  /// 中 — 焦点环展开、纸被拈起
  static const Duration medium = Duration(milliseconds: 200);

  /// 长 — 卡片落桌、分区转场
  static const Duration long = Duration(milliseconds: 320);

  /// 漂流 — 信件抵达 / DeskScene 首屏
  static const Duration drift = Duration(milliseconds: 480);

  /// 轻提示停留时长（非动效时长——入场/退场动画用 medium）
  static const Duration toastDuration = Duration(milliseconds: 2400);

  /// 纸感缓动 — decelerate 系
  static const Cubic easing = Cubic(0.2, 0, 0, 1);

  /// 漂流缓动 — 风送来的飘
  static const Cubic driftEasing = Cubic(0.3, 0, 0.2, 1);
}
