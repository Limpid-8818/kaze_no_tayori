import 'package:flutter/animation.dart' show Cubic;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

void main() {
  group('NatsuColors v2', () {
    test('五层核心色值', () {
      // 环境
      expect(NatsuColors.skyTop, const Color(0xFFC9E2F2));
      expect(NatsuColors.skyHorizon, const Color(0xFFFAF8F1));
      expect(NatsuColors.sunlight, const Color(0xFFFFF6DF));
      // 纸面
      expect(NatsuColors.paperWhite, const Color(0xFFFFFFFF));
      expect(NatsuColors.envelope, const Color(0xFFFCF9F2));
      // 墨
      expect(NatsuColors.inkBlue, const Color(0xFF2B3A55));
      // 点綴
      expect(NatsuColors.skyBlue, const Color(0xFF1F6FA8));
      expect(NatsuColors.coralStamp, const Color(0xFFE07A5F));
      expect(NatsuColors.sunlightYellow, const Color(0xFFE8B84B));
      // 状态
      expect(NatsuColors.scrim, const Color(0x732B3A55));
    });

    test('天空渐变 stops 让暖色只占底部', () {
      expect(NatsuColors.skyGradient.stops!.last, 0.72);
      expect(NatsuColors.skyGradient.colors.first, NatsuColors.skyTop);
      expect(NatsuColors.skyGradient.colors.last, NatsuColors.skyHorizon);
    });
  });

  group('字体三角色（中文优先回落链）', () {
    test('UI = sans，标题不再是衬线', () {
      expect(NatsuTypography.display.fontFamily, 'NotoSansSC');
      expect(
        NatsuTypography.display.fontFamilyFallback,
        contains('NotoSansJP'),
      );
      expect(NatsuTypography.heading.fontFamily, 'NotoSansSC');
      expect(NatsuTypography.body.fontFamily, 'NotoSansSC');
    });

    test('手写 = LXGW WenKai + KleeOne 回退', () {
      expect(NatsuTypography.hwBody.fontFamily, 'LXGWWenKai');
      expect(NatsuTypography.hwBody.fontFamilyFallback, contains('KleeOne'));
      expect(
        NatsuTypography.hwPostscript.fontFamily,
        NatsuTypography.hwAddress.fontFamily,
      );
    });

    test('衬线只活在 quoteSerif 一处', () {
      expect(NatsuTypography.quoteSerif.fontFamily, 'NotoSerifSC');
      expect(
        NatsuTypography.quoteSerif.fontFamilyFallback,
        contains('NotoSerifJP'),
      );
      final allStyles = <TextStyle>[
        NatsuTypography.display,
        NatsuTypography.heading,
        NatsuTypography.subheading,
        NatsuTypography.body,
        NatsuTypography.bodyStrong,
        NatsuTypography.bodySecondary,
        NatsuTypography.caption,
        NatsuTypography.kicker,
        NatsuTypography.label,
        NatsuTypography.button,
        NatsuTypography.meta,
        NatsuTypography.hwLetter,
        NatsuTypography.hwBody,
        NatsuTypography.hwAddress,
        NatsuTypography.hwPostscript,
        NatsuTypography.hwNote,
        NatsuTypography.hwSeal,
      ];
      for (final s in allStyles) {
        expect(
          s.fontFamily,
          isNot('NotoSerifSC'),
          reason: '衬线越界：${s.fontFamily}',
        );
      }
    });
  });

  group('动效 v2', () {
    test('四档时长 + 双曲线 + Toast 停留', () {
      expect(NatsuMotion.short.inMilliseconds, 120);
      expect(NatsuMotion.drift.inMilliseconds, 480);
      expect(NatsuMotion.easing, const Cubic(0.2, 0, 0, 1));
      expect(NatsuMotion.driftEasing, const Cubic(0.3, 0, 0.2, 1));
      expect(NatsuMotion.toastDuration.inMilliseconds, 2400);
    });
  });

  group('阴影 v2', () {
    test('纸面三级阴影存在且向下偏移', () {
      expect(NatsuShadows.paperResting, isNotEmpty);
      expect(NatsuShadows.paperHover.first.offset.dy, greaterThan(0));
      expect(
        NatsuShadows.letterResting.first.blurRadius,
        greaterThan(NatsuShadows.paperResting.first.blurRadius),
      );
    });
  });
}
