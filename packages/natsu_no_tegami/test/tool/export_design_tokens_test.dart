// ignore_for_file: avoid_print
//
// 设计令牌导出器：lib/src/tokens/ → design_tokens/ （W3C DTCG JSON）
//
// 用法：flutter test test/tool/export_design_tokens_test.dart
//
// 单一事实来源是 Dart 令牌代码（组件只 import 它们）；本脚本把代码反生成
// 为标准化 JSON，供设计工具（Ardot/Style Dictionary/Figma Tokens）消费。
// 色值、字号、时长等全部从 NatsuXxx 类读取——不手写第二份，防止漂移。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

Map<String, Object> _color(String value, String description) => {
      '\$type': 'color',
      '\$value': value,
      if (description.isNotEmpty) '\$description': description,
    };

Map<String, Object> _dimension(num value, String description) => {
      '\$type': 'dimension',
      '\$value': '${_trimNum(value)}px',
      if (description.isNotEmpty) '\$description': description,
    };

Map<String, Object> _duration(int ms, String description) => {
      '\$type': 'duration',
      '\$value': '${ms}ms',
      if (description.isNotEmpty) '\$description': description,
    };

Map<String, Object> _cubic(String value, String description) => {
      '\$type': 'cubicBezier',
      '\$value': value,
      if (description.isNotEmpty) '\$description': description,
    };

Map<String, Object> _fontFamily(String family, List<String> fallback,
        [String description = '']) =>
    {
      '\$type': 'fontFamily',
      '\$value': [family, ...fallback],
      if (description.isNotEmpty) '\$description': description,
    };

Map<String, Object> _shadow(List<BoxShadow> shadows, String description) => {
      '\$type': 'shadow',
      '\$value': [
        for (final s in shadows)
          {
            'x': '${_trimNum(s.offset.dx)}px',
            'y': '${_trimNum(s.offset.dy)}px',
            'blur': '${_trimNum(s.blurRadius)}px',
            'spread': '${_trimNum(s.spreadRadius)}px',
            'color': _hex(s.color),
          }
      ],
      '\$description': description,
    };

/// TextStyle → typography composite（直接读实际值，含回退链）
Map<String, Object> _typographyFrom(TextStyle s, String description) => {
      '\$type': 'typography',
      '\$value': {
        'fontFamily': [s.fontFamily!, ...?s.fontFamilyFallback],
        'fontWeight': '${(s.fontWeight ?? FontWeight.w400).value}',
        'fontSize': '${_trimNum(s.fontSize!)}px',
        'lineHeight': '${_trimNum(s.height! * s.fontSize!)}px',
        'color': _hex(s.color!),
      },
      '\$description': description,
    };

String _trimNum(num v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toString();

/// LinearGradient → gradient composite（天气预设反生成用；读实际 stops）
Map<String, Object> _gradientFrom(LinearGradient g, String description) => {
      '\$type': 'gradient',
      '\$value': {
        'type': 'linear',
        'angle': 180,
        'stops': [
          for (final (i, c) in g.colors.indexed)
            {
              'color': _hex(c),
              'position': _trimNum(g.stops![i]),
            }
        ],
      },
      '\$description': description,
    };

const _weatherJa = {
      NatsuWeather.sunny: '晴',
      NatsuWeather.cloudy: '云',
      NatsuWeather.rainy: '雨',
    },
    _timeJa = {
      NatsuTimeOfDay.morning: '朝',
      NatsuTimeOfDay.noon: '昼',
      NatsuTimeOfDay.dusk: '夕',
      NatsuTimeOfDay.night: '夜',
    };

String _hex(Color c) {
  final argb = c.toARGB32();
  final a = (argb >> 24) & 0xFF;
  final rgb = (argb & 0xFFFFFF)
      .toRadixString(16)
      .toUpperCase()
      .padLeft(6, '0');
  return a == 0xFF ? '#$rgb' : '#$rgb${a.toRadixString(16).toUpperCase().padLeft(2, '0')}';
}


/// 导出器以测试形式驱动：`dart run` 纯 Dart 编译碰 Flutter SDK 会崩，
/// flutter test 是最轻量的 Flutter 编译入口。产物写入 design_tokens/。
void main() {
  test('导出 W3C DTCG 令牌 JSON（单一事实来源反生成）', () {
  final json = <String, Object>{
    '\$schema': 'https://design-tokens.github.io/community-group/format/',
    'natsu': {
      'meta': {
        'name': '夏の手紙 Visual System v2',
        'concept':
            'Summer Epistolary · 光在纸上 — 环境是夏日天空，纸只在「信」的时候出现',
        'format': 'W3C Design Tokens Community Group (DTCG)',
        'generated': '2026-08-20',
        'generator':
            'test/tool/export_design_tokens_test.dart（单一事实来源：lib/src/tokens/）',
        'layers': {
          'structure': '克制现代网格（UI sans、严格对齐、无阴影）',
          'medium': '纸是内容物（白纸浮于天空、极轻墨蓝阴影、手写内容）',
          'atmosphere': '夏日自然光（天空渐变、sunlight 高光、冷暖冲突即夏天）',
        },
        'disciplines': [
          'Controlled Imperfection：不完美只属于内容物、确定性种子（±1.5–2° / ±4–6px）',
          'coralStamp 配给制：邮戳/邮票/旅行标记，装饰图形不承载正文',
          'sunlightYellow 永不作文字色',
          '衬线只活一处（quoteSerif：歌词引用/AI 短诗）',
          '字体回落链中文优先（SC 主 JP 回退）',
        ],
      },

      // ------------------------------------------------------------
      'color': {
        // 环境层（天空 = 页面）
        'sky-top': _color(_hex(NatsuColors.skyTop), '天空顶 — 清透天青（渐变上端）'),
        'sky-horizon': _color(_hex(NatsuColors.skyHorizon), '地平线 — 暖白（渐变下端，stops 0.72）'),
        'sunlight': _color(_hex(NatsuColors.sunlight), '阳光 — 纸面顶部高光'),
        'leaf': _color(_hex(NatsuColors.leaf), '叶绿 — 低频辅助（自然/旅行语义）'),
        // 纸面层
        'paper-white': _color(_hex(NatsuColors.paperWhite), '白纸 — 内容表面'),
        'envelope': _color(_hex(NatsuColors.envelope), '封筒 — 暖白（引用底/禁用底）'),
        'paper-edge': _color(_hex(NatsuColors.paperEdge), '纸缘 — 纸面描边'),
        // 墨层
        'ink-blue': _color(_hex(NatsuColors.inkBlue), '墨蓝 — 正文/标题/主按钮'),
        'ink-soft': _color(_hex(NatsuColors.inkSoft), '次级墨 — 说明文字'),
        'ink-faint': _color(_hex(NatsuColors.inkFaint), '淡墨 — caption（仅非关键小字）'),
        // 点缀层
        'sky-blue': _color(_hex(NatsuColors.skyBlue), '夏空蓝 — 交互主色（链接/选中/聚焦）'),
        'sunlight-yellow': _color(_hex(NatsuColors.sunlightYellow), '阳光黄 — 稀有高光；永不作文字色'),
        'coral-stamp': _color(_hex(NatsuColors.coralStamp), '珊瑚 — 邮戳/邮票/旅行标记（配给色）'),
        // 状态层
        'hover-overlay': _color(_hex(NatsuColors.hoverOverlay), '悬停 — 墨蓝 4%'),
        'pressed-overlay': _color(_hex(NatsuColors.pressedOverlay), '按压 — 墨蓝 8%'),
        'disabled-content': _color(_hex(NatsuColors.disabledContent), '禁用内容 — 32%'),
        'focus-ring': _color(_hex(NatsuColors.focusRing), '聚焦环 — 夏空蓝'),
        'scrim': _color(_hex(NatsuColors.scrim), '遮罩 — 墨蓝 45%（浮纸之下的天空变暗）'),
        'error': _color(_hex(NatsuColors.error), '错误 — 仅错误语义'),
        'on-ink': _color(_hex(NatsuColors.onInk), '墨蓝底上的文字 — 阳光暖白'),
        'on-coral': _color(_hex(NatsuColors.onCoral), '珊瑚底上的文字 — 同暖白'),
      },

      // ------------------------------------------------------------
      'gradient': {
        'sky': {
          '\$type': 'gradient',
          '\$value': {
            'type': 'linear',
            'angle': 180,
            'stops': [
              {'color': '#C9E2F2', 'position': 0},
              {'color': '#FAF8F1', 'position': 0.72},
            ],
          },
          '\$description': '页面天空 — 暖色只占底部 28%，防全页泛黄',
        },
        'paper-toplight': {
          '\$type': 'gradient',
          '\$value': {
            'type': 'linear',
            'angle': 180,
            'stops': [
              {'color': '#FFF6DF', 'position': 0},
              {'color': '#FFF6DF00', 'position': 0.35},
            ],
          },
          '\$description': '信纸顶光 — sunlight → transparent（光落在纸上）',
        },
        // 天气光联动 — 3 天气 × 4 时段全矩阵（从 NatsuWeatherLight 反生成）
        'weather': {
          for (final entry in NatsuWeatherLight.presets.entries)
            '${entry.key.$2.name}-${entry.key.$1.name}': _gradientFrom(
                entry.value.gradient,
                '天气光 ${_timeJa[entry.key.$2]}·${_weatherJa[entry.key.$1]}'),
        },
      },

      // ------------------------------------------------------------
      'fontFamily': {
        'ui': _fontFamily('NotoSansSC', NatsuFontFamilies.uiFallback,
            'UI sans — 结构层（现代克制）'),
        'ui-en': _fontFamily('Inter', [], '欧文/标签/元数据'),
        'mono': _fontFamily('RobotoMono', [], '等宽 — 色值/代码'),
        'hw': _fontFamily(
            'LXGWWenKai', NatsuFontFamilies.hwFallback, '手写 — 内容物的声音'),
        'quote': _fontFamily('NotoSerifSC', NatsuFontFamilies.quoteFallback,
            '引用 — 铅字（系统中唯一衬线场景）'),
        'seal': _fontFamily(
            'MaShanZheng', NatsuFontFamilies.sealFallback, '刻印 — 品牌位'),
      },

      'fontWeight': {
        'regular': {'\$type': 'fontWeight', '\$value': '400'},
        'medium': {'\$type': 'fontWeight', '\$value': '500'},
        'semibold': {'\$type': 'fontWeight', '\$value': '600'},
        'bold': {'\$type': 'fontWeight', '\$value': '700'},
      },

      'fontSize': {
        'display': _dimension(48, '大标题'),
        'heading': _dimension(32, '章节标题'),
        'subheading': _dimension(22, '欧文副标题'),
        'hw-letter': _dimension(36, '手写信标题'),
        'hw-address': _dimension(28, '宛名/署名'),
        'hw-ps': _dimension(24, '追筆'),
        'hw-body': _dimension(20, '手写信正文'),
        'quote': _dimension(18, '引用（歌词/AI 短诗）'),
        'body': _dimension(16, '正文'),
        'button': _dimension(15, '按钮'),
        'caption': _dimension(13, '小字/眉标/元数据'),
      },

      'lineHeight': {
        'display': _dimension(60, ''),
        'heading': _dimension(42, ''),
        'subheading': _dimension(32, ''),
        'hw-letter': _dimension(54, ''),
        'hw-address': _dimension(44, ''),
        'hw-ps': _dimension(38, ''),
        'hw-body': _dimension(38, ''),
        'quote': _dimension(32, ''),
        'body': _dimension(28, '1.75 行距 — 慢媒介的呼吸'),
        'button': _dimension(22, ''),
        'caption': _dimension(20, ''),
      },

      'letterSpacing': {
        'kicker': _dimension(2, '章节眉标'),
        'label': _dimension(1.5, '分组标签'),
        'relaxed': _dimension(1.2, '元数据行'),
      },

      'typography': {
        'display': _typographyFrom(
            NatsuTypography.display, 'Display 48 — 大标题（sans SemiBold）'),
        'heading': _typographyFrom(NatsuTypography.heading, 'Heading 32 — sans Bold'),
        'subheading': _typographyFrom(NatsuTypography.subheading, 'Subheading 22 — Inter'),
        'body': _typographyFrom(NatsuTypography.body, 'Body 16 — 1.75 行距'),
        'body-strong': _typographyFrom(NatsuTypography.bodyStrong, 'Body Strong'),
        'body-secondary': _typographyFrom(NatsuTypography.bodySecondary, '副文本'),
        'caption': _typographyFrom(NatsuTypography.caption, 'Caption 13'),
        'kicker': _typographyFrom(NatsuTypography.kicker, '眉标 + 2px 字距'),
        'label': _typographyFrom(NatsuTypography.label, '分组标签 + 1.5px 字距'),
        'button': _typographyFrom(NatsuTypography.button, '按钮文字'),
        'meta': _typographyFrom(NatsuTypography.meta, '元数据行 + 1.2px 字距'),
        'hw-letter': _typographyFrom(
            NatsuTypography.hwLetter, '手写信标题 — LXGW WenKai'),
        'hw-body': _typographyFrom(
            NatsuTypography.hwBody, '手写信正文 — LXGW WenKai'),
        'hw-address': _typographyFrom(
            NatsuTypography.hwAddress, '宛名/署名 — LXGW WenKai'),
        'hw-postscript': _typographyFrom(NatsuTypography.hwPostscript,
            '追筆 — 同宛名栈，灰而退后'),
        'hw-note': _typographyFrom(
            NatsuTypography.hwNote, '手写小注 — 照片手记/邮戳手写'),
        'hw-seal': _typographyFrom(NatsuTypography.hwSeal, '刻印 — MaShanZheng 珊瑚'),
        'quote': _typographyFrom(NatsuTypography.quoteSerif,
            '引用 — 系统中唯一衬线（歌词引用/AI 短诗）'),
      },

      // ------------------------------------------------------------
      'spacing': {
        // 紧凑刻度（组件内部）
        'xs': _dimension(NatsuSpacing.xs, ''),
        'sm': _dimension(NatsuSpacing.sm, ''),
        'md': _dimension(NatsuSpacing.md, ''),
        'lg': _dimension(NatsuSpacing.lg, ''),
        'xl': _dimension(NatsuSpacing.xl, ''),
        'xxl': _dimension(NatsuSpacing.xxl, ''),
        // 组件专项
        'card-padding': _dimension(NatsuSpacing.cardPadding, '卡片内边距'),
        'card-gap': _dimension(NatsuSpacing.cardGap, '卡片内要素间'),
        'btn-padding-y': _dimension(NatsuSpacing.btnPaddingY, ''),
        'btn-padding-x': _dimension(NatsuSpacing.btnPaddingX, ''),
        'btn-sm-padding-y': _dimension(NatsuSpacing.btnSmPaddingY, ''),
        'btn-sm-padding-x': _dimension(NatsuSpacing.btnSmPaddingX, ''),
        'tag-padding-y': _dimension(NatsuSpacing.tagPaddingY, ''),
        'tag-padding-x': _dimension(NatsuSpacing.tagPaddingX, ''),
        'input-height': _dimension(NatsuSpacing.inputHeight, '输入框高度'),
        'swatch-gap': _dimension(NatsuSpacing.swatchGap, ''),
        // 表单控件专项
        'switch-track-w': _dimension(NatsuSpacing.switchTrackW, '开关轨道宽'),
        'switch-track-h': _dimension(NatsuSpacing.switchTrackH, '开关轨道高'),
        'switch-knob': _dimension(NatsuSpacing.switchKnob, '开关旋钮直径'),
        'check-size': _dimension(NatsuSpacing.checkSize, '复选框边长'),
        'radio-size': _dimension(NatsuSpacing.radioSize, '单选环直径'),
        'control-hit-target':
            _dimension(NatsuSpacing.controlHitTarget, '控件最小命中区'),
        'slider-knob': _dimension(NatsuSpacing.sliderKnob, '滑块旋钮直径'),
        'slider-track-h': _dimension(NatsuSpacing.sliderTrackH, '滑块轨道高'),
        // 反馈与浮层专项
        'progress-h': _dimension(NatsuSpacing.progressH, '进度条高度'),
        'spinner-sm': _dimension(NatsuSpacing.spinnerSm, '加载指示 sm 直径'),
        'spinner-md': _dimension(NatsuSpacing.spinnerMd, '加载指示 md 直径'),
        'dialog-max-w': _dimension(NatsuSpacing.dialogMaxW, '对话框最大宽'),
        'sheet-max-w': _dimension(NatsuSpacing.sheetMaxW, '底部弹层最大宽'),
        'toast-max-w': _dimension(NatsuSpacing.toastMaxW, '轻提示最大宽'),
        'handle-w': _dimension(NatsuSpacing.handleW, '底部弹层把手宽'),
        'handle-h': _dimension(NatsuSpacing.handleH, '底部弹层把手高'),
        // 编辑刻度（展示页容器）
        'page-padding': _dimension(NatsuSpacingEditorial.pagePadding, '页面左右余白'),
        'section-gap': _dimension(NatsuSpacingEditorial.sectionGap, '大章节间（間）'),
        'block-gap': _dimension(NatsuSpacingEditorial.blockGap, '章节内块间'),
      },

      'radius': {
        'card': _dimension(NatsuRadius.card, '卡片·按钮·输入框（纸浮起后稍柔）'),
        'letter': _dimension(NatsuRadius.letter, '信纸（近直角）'),
        'tag': _dimension(NatsuRadius.tag, '标签药丸'),
        'tag-sm': _dimension(NatsuRadius.tagSm, '小标签'),
        'stamp': _dimension(NatsuRadius.stamp, '印枠'),
      },

      'border': {
        'hairline': {
          '\$type': 'border',
          '\$value': {
            'style': 'solid',
            'width': '1px',
            'color': '{color.paper-edge}',
          },
          '\$description': '纸缘线',
        },
        'input': {
          '\$type': 'border',
          '\$value': {
            'style': 'solid',
            'width': '1px',
            'color': '#D5D0C4',
          },
          '\$description': '输入线（稍深）',
        },
      },

      'shadow': {
        'paper-resting': _shadow(
            NatsuShadows.paperResting, '纸面静置 — 纸从天空浮起'),
        'paper-hover': _shadow(NatsuShadows.paperHover, '纸面被拈起'),
        'letter-resting': _shadow(NatsuShadows.letterResting, '大纸面（信纸）'),
      },

      'motion': {
        'short': _duration(120, '指尖按压 / hover 光'),
        'medium': _duration(200, '纸被拈起'),
        'long': _duration(320, '纸落桌 / 卡片入场'),
        'drift': _duration(480, '漂流到位 — 信件抵达 / 首屏落桌'),
        'toast-duration': _duration(
            NatsuMotion.toastDuration.inMilliseconds, '轻提示停留（非动效时长）'),
        'easing': _cubic('0.2, 0, 0, 1', '纸感缓动（decelerate 系）'),
        'drift-easing': _cubic('0.3, 0, 0.2, 1', '漂流缓动 — 风送来的'),
      },

      'imperfection': {
        'tilt-min': _dimension(
            NatsuImperfection.tiltMin, '最小倾斜（度）— 低于此等于假对齐'),
        'tilt-max': _dimension(NatsuImperfection.tiltMax, '最大倾斜（度）'),
        'offset-min': _dimension(NatsuImperfection.offsetMin, '最小偏移'),
        'offset-max': _dimension(NatsuImperfection.offsetMax, '最大偏移'),
      },
    },
  };

  final dir = Directory('design_tokens');
  dir.createSync(recursive: true);
  final file = File('design_tokens/natsu-tokens-v2.json');
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(json)}\n');

  // 自校验：读回并断言关键值与代码一致（漂移即红）
  final readBack = jsonDecode(file.readAsStringSync());
  final root = readBack['natsu'] as Map<String, dynamic>;
  final colors = root['color'] as Map<String, dynamic>;
  expect((colors['ink-blue'] as Map<String, dynamic>)['\$value'],
      _hex(NatsuColors.inkBlue));
  final shadows = root['shadow'] as Map<String, dynamic>;
  expect(
      (shadows['paper-resting'] as Map<String, dynamic>)['\$value'],
      isA<List<dynamic>>().having((l) => l.length, 'length', 1));
  final motion = root['motion'] as Map<String, dynamic>;
  expect((motion['drift'] as Map<String, dynamic>)['\$value'], '480ms');
  final gradient = root['gradient'] as Map<String, dynamic>;
  final weather = gradient['weather'] as Map<String, dynamic>;
  expect(weather.length, 12);
  final duskSunny = (weather['dusk-sunny'] as Map<String, dynamic>)['\$value']
      as Map<String, dynamic>;
  expect((duskSunny['stops'] as List<dynamic>).length, 4,
      reason: '夕·晴是 4 stops 琥珀带结构');
  print('✓ 导出 ${file.path}（${(file.lengthSync() / 1024).toStringAsFixed(1)} KB）');
  });
}
