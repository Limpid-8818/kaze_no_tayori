import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

/// 天气光令牌仲裁 — 全矩阵完整性、回归基准、渐变结构合法性。
/// 色值对比度另由 contrast_test.dart 的全矩阵断言锁定。
void main() {
  test('全矩阵：3 天气 × 4 时段 = 12 条预设，of() 全覆盖', () {
    expect(NatsuWeatherLight.presets.length, 12);
    for (final weather in NatsuWeather.values) {
      for (final time in NatsuTimeOfDay.values) {
        final preset = NatsuWeatherLight.of(weather, time);
        expect(
          preset.gradient,
          isA<LinearGradient>(),
          reason: '$weather × $time 缺预设',
        );
      }
    }
  });

  test('回归基准：昼·晴 == v2 默认天空（同一 const，colors/stops 逐项相等）', () {
    final base = NatsuWeatherLight.noonSunny.gradient;
    expect(
      identical(base, NatsuColors.skyGradient),
      isTrue,
      reason: '昼·晴必须直接引用 skyGradient——它是其他 11 条的回归锚点',
    );
    expect(base.colors, equals(NatsuColors.skyGradient.colors));
    expect(base.stops, equals(NatsuColors.skyGradient.stops));
  });

  test('渐变结构：colors 与 stops 等长、stops 严格递增、首 0 尾 <1', () {
    for (final entry in NatsuWeatherLight.presets.entries) {
      final g = entry.value.gradient;
      final key = '${entry.key.$1} × ${entry.key.$2}';
      expect(
        g.colors.length,
        g.stops!.length,
        reason: '$key：colors/stops 长度不一致',
      );
      expect(g.begin, Alignment.topCenter, reason: '$key：begin 必须 topCenter');
      expect(g.end, Alignment.bottomCenter, reason: '$key：end 必须 bottomCenter');
      expect(g.stops!.first, 0.0, reason: '$key：首 stop 必须 0');
      expect(g.stops!.last, lessThan(1.0), reason: '$key：尾 stop 必须 <1');
      for (var i = 1; i < g.stops!.length; i++) {
        expect(
          g.stops![i],
          greaterThan(g.stops![i - 1]),
          reason: '$key：stops 必须严格递增（第 $i 段）',
        );
      }
    }
  });

  test('夕的 4 stops：琥珀带占中腹部（暖色止于 0.78，非底部全暖）', () {
    for (final weather in NatsuWeather.values) {
      final stops = NatsuWeatherLight.of(
        weather,
        NatsuTimeOfDay.dusk,
      ).gradient.stops!;
      expect(stops.length, 4, reason: '$weather · 夕必须是 4 stops 的琥珀带结构');
    }
    // 朝/昼/夜保持两 stops 的经典结构
    for (final time in [
      NatsuTimeOfDay.morning,
      NatsuTimeOfDay.noon,
      NatsuTimeOfDay.night,
    ]) {
      for (final weather in NatsuWeather.values) {
        expect(
          NatsuWeatherLight.of(weather, time).gradient.stops!.length,
          2,
          reason: '$weather · $time 保持 [0.0, 0.72] 两 stops',
        );
      }
    }
  });
}
