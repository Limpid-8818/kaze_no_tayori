/// 两点直线距离标签 —— 「230m / 1.2km」。
///
/// 发掘列表卡的位置信息槽用：读者坐标 × 信的落点坐标（2026-08 起
/// discover 随响应下发 lat/lon）。任一端缺席就返回 null（不显示距离）。
library;

import 'package:geolocator/geolocator.dart';

String? distanceLabelBetween({
  required double? startLat,
  required double? startLon,
  required double? endLat,
  required double? endLon,
}) {
  if (startLat == null ||
      startLon == null ||
      endLat == null ||
      endLon == null) {
    return null;
  }
  final meters = Geolocator.distanceBetween(startLat, startLon, endLat, endLon);
  if (meters < 1000) return '${meters.round()}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}
