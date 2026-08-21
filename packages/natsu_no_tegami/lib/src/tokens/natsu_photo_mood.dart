import 'dart:ui' show Color, ColorFilter, ImageFilter;

import 'package:flutter/painting.dart' show Alignment, LinearGradient;

/// 夏の手紙 v2 · 照片 mood 令牌 — 按下快门的那一瞬间
///
/// 三种可选 mood（+ 素）：写信时选，不默认硬加——质感与照片本身的
/// 特征相关，过曝属于正午的海，逆光属于黄昏的电车，横糊属于追不上的风。
///
/// 与 PhotoCard 内建质感（颗粒/阳光斜带/暖边）语义正交：内建层表达
/// 「相纸介质」的存在，mood 表达「拍摄瞬间」的状态——叠加不替代。
///
/// 全部 const，零运行时构造。
enum PhotoMood {
  /// 素 — 不加拍摄瞬间处理，只有相纸介质层
  none,

  /// 过曝 — 正午强光，高光溢出（提亮矩阵 + 顶部白溢渐变）
  overexposed,

  /// 逆光 — 对着光按的快门（压亮 + 暗部泛蓝 + 径向暗角）
  backlit,

  /// 运动模糊 — 手在抖/在跑/在车上（横向各向异性 blur）
  motion,
}

abstract final class NatsuPhotoMood {
  /// 过曝色彩矩阵 — R/G 提亮 1.16、B 1.10：整体偏暖不是偏蓝，
  /// 基抬 14/10 让暗部也被夏季的空气洗开
  static const ColorFilter overexposedFilter = ColorFilter.matrix([
    1.16,
    0,
    0,
    0,
    14,
    0,
    1.16,
    0,
    0,
    14,
    0,
    0,
    1.10,
    0,
    10,
    0,
    0,
    0,
    1,
    0,
  ]);

  /// 过曝顶部溢出 — 白色从顶往下洗开（0x59 ≈ 35% 白）
  static const LinearGradient overexposedWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.45],
  );

  /// 逆光色彩矩阵 — 亮度压 0.92（对着光，主体成剪影）、
  /// 蓝通道增益 1.08（暗部泛蓝——暮色里的视网膜）、alpha 1.15 提对比
  static const ColorFilter backlitFilter = ColorFilter.matrix([
    0.92,
    0,
    0,
    0,
    0,
    0,
    0.92,
    0,
    0,
    0,
    0,
    0,
    1.08,
    0,
    6,
    0,
    0,
    0,
    1.15,
    0,
  ]);

  /// 逆光暗角 — 中心留光（sunlight 14%），四角沉入墨蓝（22%）
  static const Color backlitVignetteCenter = Color(0x00FFF6DF);
  static const Color backlitVignetteEdge = Color(0x382B3A55);

  /// 暗角半径（相对最短边）与中心亮度驻留比例
  static const double backlitVignetteRadius = 0.9;
  static const double backlitVignetteFocal = 0.55;

  /// 运动模糊 — 横向 3 倍于纵向的 blur：横移的手感（追焦失败）
  static const double motionSigmaX = 2.4;
  static const double motionSigmaY = 0.8;

  static ImageFilter motionBlur() =>
      ImageFilter.blur(sigmaX: motionSigmaX, sigmaY: motionSigmaY);
}
