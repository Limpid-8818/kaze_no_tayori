import 'package:flutter/material.dart';

import '../../tokens/natsu_tokens.dart';

/// 夏の手紙 v2 · 竖排手写 — 纵书的宛名与署名
///
/// Flutter 无内建竖排；这里是单字 Column 的零依赖实现：
/// - `text.characters` 拆字（代理对安全），每字一个 Text
/// - 字间间距由 [glyphGap] 补足（竖排里 TextStyle 行高不参与字距）；
///   null = `NatsuTypography.verticalAddressGap` 令牌
/// - 长音与引号类按日文竖排传统旋转 90°（RotatedBox）；
///   汉字/假名/中文标点直立——已知简化：不做小书体与标点悬挂
/// - [maxHeight] 给定时溢出换列，竖排从右读到左（新列在左）
///
/// 信封宛名用此组件（hwAddress 的竖排形态）——和式纵形封筒的正统；
/// 信尾署名已定版为横排（见 LetterReading）。
class VerticalHandwriting extends StatelessWidget {
  const VerticalHandwriting({
    super.key,
    required this.text,
    this.style,
    this.glyphGap,
    this.maxHeight,
  });

  final String text;

  /// null = NatsuTypography.hwAddress（宛名/署名本来的样式）
  final TextStyle? style;

  /// 字间额外间距；null = verticalAddressGap 令牌
  final double? glyphGap;

  /// 给定时溢出换列（列从右往左续）
  final double? maxHeight;

  /// 竖排中应旋转 90° 的字符（日文纵书传统：长音与引号）
  static const _rotated = {'ー', '（', '）', '「', '」', '『', '』'};

  @override
  Widget build(BuildContext context) {
    final effective = style ?? NatsuTypography.hwAddress;
    // 竖排单字：行高压到 1.0（行高不参与竖排字距，由 glyphGap 接管）
    final glyphStyle = effective.copyWith(height: 1.0);
    final gap = glyphGap ?? NatsuTypography.verticalAddressGap;

    final chars = text.characters.toList();
    final columns = maxHeight == null
        ? [chars]
        : _splitColumns(chars, effective.fontSize ?? 28, gap, maxHeight!);

    // 竖排从右读到左：视觉顺序（左→右）= 阅读顺序的逆序
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final col in columns.reversed)
          Padding(
            padding: EdgeInsets.only(left: col == columns.last ? 0 : gap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < col.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  _glyph(col[i], glyphStyle),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _glyph(String c, TextStyle style) {
    if (_rotated.contains(c)) {
      return RotatedBox(quarterTurns: 1, child: Text(c, style: style));
    }
    return Text(c, style: style);
  }

  /// 按每列可容纳字数切列（估算：字号 + 字距；宛名长度可控，
  /// 不做 TextPainter 精确测量——过度工程）
  static List<List<String>> _splitColumns(
    List<String> chars,
    double fontSize,
    double gap,
    double maxHeight,
  ) {
    final perColumn = ((maxHeight + gap) / (fontSize + gap)).floor().clamp(
      1,
      chars.length,
    );
    if (perColumn >= chars.length) return [chars];
    return [
      for (var i = 0; i < chars.length; i += perColumn)
        chars.sublist(i, (i + perColumn).clamp(0, chars.length)),
    ];
  }
}
