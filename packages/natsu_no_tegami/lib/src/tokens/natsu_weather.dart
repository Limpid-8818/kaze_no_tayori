import 'dart:ui' show Color;

import 'package:flutter/painting.dart'
    show Alignment, LinearGradient;

import 'natsu_colors.dart';

/// 天气 — 信携带的环境维度之一
enum NatsuWeather { sunny, cloudy, rainy }

/// 时段 — 信携带的环境维度之二
enum NatsuTimeOfDay { morning, noon, dusk, night }

/// 单个天空预设 — 渐变恒为 topCenter → bottomCenter
final class NatsuSkyPreset {
  /// 页面天空渐变（端点色已过对比度仲裁）
  final LinearGradient gradient;

  /// 该天色下的阳光色 — 纸面顶光联动源（夜 = 月光）
  final Color sunlight;

  const NatsuSkyPreset(this.gradient, this.sunlight);
}

/// 夏の手紙 v2 · 天气光令牌 — 「信携带的天气，落在环境上」
///
/// 天气光联动的令牌层：环境（天空渐变）随信携带的 [NatsuWeather] ×
/// [NatsuTimeOfDay] 切换氛围；纸面（paperWhite）永远不动——变的是光，
/// 不是信。
///
/// 设计规律（色值挑选时保持的正交梯度）：
/// - 同时段沿 晴→云→雨：饱和度递减、灰度递增
/// - 同天气沿 朝→昼→夕→夜：朝淡粉、昼清透、夕琥珀、夜冷银
/// - 夕是唯一 4 stops 的时段：琥珀带占画面中腹部（金色时刻），
///   顶端保留冷天青——夏天不能变成秋天
/// - 夜是「月光调」而非暗夜：全表最深的夜·雨 top（#B9C7D6）依旧够亮，
///   墨蓝正文在任何天色下 ≥4.5（contrast_test 全矩阵锁定）
///
/// 纪律：
/// - 全部 const、零运行时色算（不做 hue 旋转/lerp 合成——不可 const）
/// - 昼·晴 == [NatsuColors.skyGradient]（回归基准，直接引用）
abstract final class NatsuWeatherLight {
  /// 昼·晴 — 回归基准：与 v2 默认天空同一 const
  static const NatsuSkyPreset noonSunny = NatsuSkyPreset(
    NatsuColors.skyGradient,
    NatsuColors.sunlight,
  );

  // ---- 朝 ---------------------------------------------------------------------
  static const NatsuSkyPreset morningSunny = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFD8E9F5), Color(0xFFFEF6EC)],
      stops: [0.0, 0.72],
    ),
    Color(0xFFFFF8E8),
  );

  static const NatsuSkyPreset morningCloudy = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFDCE4EA), Color(0xFFF4F1EE)],
      stops: [0.0, 0.72],
    ),
    Color(0xFFFAF3E9),
  );

  static const NatsuSkyPreset morningRainy = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFCFDAE2), Color(0xFFEDF0F1)],
      stops: [0.0, 0.72],
    ),
    Color(0xFFF1F0E7),
  );

  // ---- 昼 ---------------------------------------------------------------------
  static const NatsuSkyPreset noonCloudy = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFD6E1E8), Color(0xFFF6F5F1)],
      stops: [0.0, 0.72],
    ),
    Color(0xFFFBF6EA),
  );

  static const NatsuSkyPreset noonRainy = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFC7D3DC), Color(0xFFEEF0F1)],
      stops: [0.0, 0.72],
    ),
    Color(0xFFF2F1E8),
  );

  // ---- 夕（4 stops：琥珀带占中腹部，顶端仍冷，暖止于 0.78）--------------------
  static const NatsuSkyPreset duskSunny = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFD3DBE6),
        Color(0xFFF0D9B4),
        Color(0xFFF9E8CE),
        Color(0xFFFFE0AC),
      ],
      stops: [0.0, 0.34, 0.62, 0.78],
    ),
    Color(0xFFFFE9C4),
  );

  static const NatsuSkyPreset duskCloudy = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFD8DCE2),
        Color(0xFFE3D3BE),
        Color(0xFFF2E6D6),
        Color(0xFFF6E3C4),
      ],
      stops: [0.0, 0.34, 0.62, 0.78],
    ),
    Color(0xFFF4E2C6),
  );

  static const NatsuSkyPreset duskRainy = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFCBD2DA),
        Color(0xFFD9CDBD),
        Color(0xFFE8E0D4),
        Color(0xFFE8DEC8),
      ],
      stops: [0.0, 0.34, 0.62, 0.78],
    ),
    Color(0xFFE9DCC4),
  );

  // ---- 夜（月光调：冷银蓝而非暗夜）--------------------------------------------
  static const NatsuSkyPreset nightSunny = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFBFCEDF), Color(0xFFE8ECF2)],
      stops: [0.0, 0.72],
    ),
    Color(0xFFE9F0F7), // 月光
  );

  static const NatsuSkyPreset nightCloudy = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFC4CEDA), Color(0xFFE9EAEE)],
      stops: [0.0, 0.72],
    ),
    Color(0xFFEAEDEF),
  );

  static const NatsuSkyPreset nightRainy = NatsuSkyPreset(
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFB9C7D6), Color(0xFFE2E7EC)],
      stops: [0.0, 0.72],
    ),
    Color(0xFFE4E9EE),
  );

  /// 全矩阵 — 3 天气 × 4 时段，查表即得（无运行时色算）
  static const Map<(NatsuWeather, NatsuTimeOfDay), NatsuSkyPreset>
      presets = {
    (NatsuWeather.sunny, NatsuTimeOfDay.morning): morningSunny,
    (NatsuWeather.sunny, NatsuTimeOfDay.noon): noonSunny,
    (NatsuWeather.sunny, NatsuTimeOfDay.dusk): duskSunny,
    (NatsuWeather.sunny, NatsuTimeOfDay.night): nightSunny,
    (NatsuWeather.cloudy, NatsuTimeOfDay.morning): morningCloudy,
    (NatsuWeather.cloudy, NatsuTimeOfDay.noon): noonCloudy,
    (NatsuWeather.cloudy, NatsuTimeOfDay.dusk): duskCloudy,
    (NatsuWeather.cloudy, NatsuTimeOfDay.night): nightCloudy,
    (NatsuWeather.rainy, NatsuTimeOfDay.morning): morningRainy,
    (NatsuWeather.rainy, NatsuTimeOfDay.noon): noonRainy,
    (NatsuWeather.rainy, NatsuTimeOfDay.dusk): duskRainy,
    (NatsuWeather.rainy, NatsuTimeOfDay.night): nightRainy,
  };

  /// 查表 — 组合必然存在（weather_test 锁定全矩阵覆盖）
  static NatsuSkyPreset of(NatsuWeather weather, NatsuTimeOfDay time) =>
      presets[(weather, time)]!;
}
