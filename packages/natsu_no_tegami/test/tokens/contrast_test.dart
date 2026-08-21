import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

/// WCAG 对比度仲裁测试——色彩可用性的最终裁决。
/// 任何色值调整必须过这里；不达标就调 hex，不放宽标准。
void main() {
  double lum(Color c) {
    double channel(int v8) {
      final v = v8 / 255.0;
      return v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = channel((c.toARGB32() >> 16) & 0xFF);
    final g = channel((c.toARGB32() >> 8) & 0xFF);
    final b = channel(c.toARGB32() & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  double ratio(Color a, Color b) {
    final l1 = lum(a);
    final l2 = lum(b);
    final hi = l1 > l2 ? l1 : l2;
    final lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('正文与关键交互色 ≥ 4.5（WCAG AA）', () {
    final pairs = <String, (Color, Color)>{
      'inkBlue on paperWhite（正文）': (
        NatsuColors.inkBlue,
        NatsuColors.paperWhite,
      ),
      'inkBlue on skyHorizon（环境上文字）': (
        NatsuColors.inkBlue,
        NatsuColors.skyHorizon,
      ),
      'inkBlue on skyTop（天空区文字）': (NatsuColors.inkBlue, NatsuColors.skyTop),
      'inkSoft on paperWhite（次级说明）': (
        NatsuColors.inkSoft,
        NatsuColors.paperWhite,
      ),
      'skyBlue on paperWhite（交互文字）': (
        NatsuColors.skyBlue,
        NatsuColors.paperWhite,
      ),
      'onInk on inkBlue（主按钮字）': (NatsuColors.onInk, NatsuColors.inkBlue),
      'onInk on skyBlue（选中态字）': (NatsuColors.onInk, NatsuColors.skyBlue),
    };
    for (final entry in pairs.entries) {
      final r = ratio(entry.value.$1, entry.value.$2);
      expect(
        r,
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key} 对比度 ${r.toStringAsFixed(2)} < 4.5',
      );
    }
  });

  test('小字色（inkFaint）≥ 3.0（非关键 caption 豁免线）', () {
    final r = ratio(NatsuColors.inkFaint, NatsuColors.paperWhite);
    expect(
      r,
      greaterThanOrEqualTo(3.0),
      reason: 'inkFaint 作为非关键 caption 至少 3.0，实际 ${r.toStringAsFixed(2)}',
    );
  });

  test('阳光黄永不作文字色（对白纸对比度必然不足，纪律自检）', () {
    final r = ratio(NatsuColors.sunlightYellow, NatsuColors.paperWhite);
    expect(
      r,
      lessThan(4.5),
      reason:
          '若 sunlightYellow 某天对纸面 ≥4.5 了，说明它变成了可文字色——'
          '但它的角色是光，不是墨。此断言反向锁定设计纪律。',
    );
  });

  test('天气光全矩阵：inkBlue 对所有预设端点色 ≥ 4.5（夜是月光调，不是暗夜）', () {
    for (final entry in NatsuWeatherLight.presets.entries) {
      final name = '${entry.key.$2}·${entry.key.$1}';
      for (final (i, color) in entry.value.gradient.colors.indexed) {
        final r = ratio(NatsuColors.inkBlue, color);
        expect(
          r,
          greaterThanOrEqualTo(4.5),
          reason:
              '$name 渐变第 $i 端点对比度 ${r.toStringAsFixed(2)} < 4.5——'
              '天色可以变，文字可读性纪律不能变。夜请往月光调调，不要压暗。',
        );
      }
    }
  });
}
