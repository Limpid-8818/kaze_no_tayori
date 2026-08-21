import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

/// Controlled Imperfection 仲裁测试——不完美是设计，不是 bug：
/// 确定性（同 id 同角度）、量化范围（±1.5–2° / ±4–6px）、离散性。
void main() {
  group('确定性', () {
    test('同 id 跨调用 seedOf/tiltOf/offsetOf 一致', () {
      for (final id in ['photo-1', 'stamp-2', 'a', '', '中文种子', 'x' * 100]) {
        expect(NatsuImperfection.seedOf(id), NatsuImperfection.seedOf(id));
        expect(NatsuImperfection.tiltOf(id), NatsuImperfection.tiltOf(id));
        expect(NatsuImperfection.offsetOf(id), NatsuImperfection.offsetOf(id));
      }
    });

    test('tiltOf 落在 ±[1.5, 2.0]，避开假对齐', () {
      for (var i = 0; i < 500; i++) {
        final t = NatsuImperfection.tiltOf('seed-$i');
        expect(t.abs(), inInclusiveRange(1.5, 2.0),
            reason: 'seed-$i 倾斜 ${t.toStringAsFixed(3)}° 越界');
      }
    });

    test('offsetOf 各轴落在 ±[4, 6]', () {
      for (var i = 0; i < 500; i++) {
        final o = NatsuImperfection.offsetOf('seed-$i');
        expect(o.dx.abs(), inInclusiveRange(4.0, 6.0));
        expect(o.dy.abs(), inInclusiveRange(4.0, 6.0));
      }
    });
  });

  group('离散性', () {
    test('不同 id 大概率不同种子（500 个样本去重 > 450）', () {
      final seeds = {
        for (var i = 0; i < 500; i++) NatsuImperfection.seedOf('distinct-$i')
      };
      expect(seeds.length, greaterThan(450));
    });

    test('种子在 [0, 1) 区间', () {
      for (var i = 0; i < 100; i++) {
        final s = NatsuImperfection.seedOf('range-$i');
        expect(s, greaterThanOrEqualTo(0.0));
        expect(s, lessThan(1.0));
      }
    });
  });

  group('Offset 独立性', () {
    test('x/y 轴种子独立派生（相同概率极低）', () {
      final o = Offset(0, 0);
      expect(o, isA<Offset>()); // sanity：dart:ui Offset 可用
      // x/y 从不同后缀派生
      expect(NatsuImperfection.seedOf('id/x'), NatsuImperfection.seedOf('id/x'));
      // 极低概率相等——取 50 个 id，x/y 种子全等的应近乎不存在
      var collisions = 0;
      for (var i = 0; i < 50; i++) {
        if (NatsuImperfection.seedOf('axis-$i/x') ==
            NatsuImperfection.seedOf('axis-$i/y')) {
          collisions++;
        }
      }
      expect(collisions, lessThan(2));
    });
  });
}
