import 'dart:math' as math;

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
/// - [maxHeight] 给定时自适应（真实信封的手写直觉——字多就写小一点，
///   而不是拆出孤字列）：
///   1. 优先单列：字号在列高预算内等比渐缩（字距随之保持密度节奏）；
///   2. 字号缩到可读下限仍放不下，转**满列平衡分列**（10 字 = 5+5，
///      列列饱满，新列在左、右列先读——纵书正统）；
///   3. [maxWidth] 给定时整块宽度兜底，超宽再缩字号防画出载面之外
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
    this.maxWidth,
  });

  final String text;

  /// null = NatsuTypography.hwAddress（宛名/署名本来的样式）
  final TextStyle? style;

  /// 字间额外间距；null = verticalAddressGap 令牌
  final double? glyphGap;

  /// 给定时自适应缩字/换列（列从右往左续）
  final double? maxHeight;

  /// 整块宽度预算；超出时按比例缩字号兜底
  final double? maxWidth;

  /// 竖排中应旋转 90° 的字符（日文纵书传统：长音与引号）
  static const _rotated = {'ー', '（', '）', '「', '」', '『', '』'};

  /// 单列可读下限：字号低于此值转满列平衡分列（hwAddress 28 号基准下
  /// 约为 9 字——10 字起双列）
  static const double _minColumnFont = 16.0;

  @override
  Widget build(BuildContext context) {
    final effective = style ?? NatsuTypography.hwAddress;
    // 竖排单字：行高压到 1.0（行高不参与竖排字距，由 glyphGap 接管）
    final glyphStyle = effective.copyWith(height: 1.0);
    final baseFontSize = effective.fontSize ?? 28.0;
    final baseGap = glyphGap ?? NatsuTypography.verticalAddressGap;

    final chars = text.characters.toList();
    if (chars.isEmpty) return const SizedBox.shrink();

    final layout = maxHeight == null
        ? (fontSize: baseFontSize, gap: baseGap, columns: [chars])
        : _resolveLayout(
            chars,
            baseFontSize: baseFontSize,
            baseGap: baseGap,
            maxHeight: maxHeight!,
            maxWidth: maxWidth,
          );
    // 仅在真正缩字时改写字号，避免把依赖继承字号的 style 钉死成估算值
    final resolvedStyle = layout.fontSize < baseFontSize
        ? glyphStyle.copyWith(fontSize: layout.fontSize)
        : glyphStyle;

    // 竖排从右读到左：视觉顺序（左→右）= 阅读顺序的逆序
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final col in layout.columns.reversed)
          Padding(
            padding: EdgeInsets.only(
              left: col == layout.columns.last ? 0 : layout.gap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < col.length; i++) ...[
                  if (i > 0) SizedBox(height: layout.gap),
                  _glyph(col[i], resolvedStyle),
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

  /// 自适应竖排布局（估算：单字宽 = 字号、列高 = 字号 + 字距；
  /// 行高压到 1.0 后该估算即精确值，不做 TextPainter 测量）
  ///
  /// - 列高预算：`n 字列高 = n×字号 + (n−1)×字距`，字距按令牌比例
  ///   `gap = k×字号` 随缩字等比收紧 → `字号 = maxHeight / (n + k(n−1))`
  /// - 列数取最小 c 使「每列 `⌈n/c⌉` 字」的字号 ≥ [_minColumnFont]；
  ///   全不满足则每列一字兜底
  /// - [maxWidth] 兜底：块宽 = `c×字号 + (c−1)×字距`，超预算整体再缩
  static ({double fontSize, double gap, List<List<String>> columns})
  _resolveLayout(
    List<String> chars, {
    required double baseFontSize,
    required double baseGap,
    required double maxHeight,
    double? maxWidth,
  }) {
    final ratio = baseGap / baseFontSize;
    double fontFor(int perColumn) => math.min(
      baseFontSize,
      maxHeight / (perColumn + ratio * (perColumn - 1)),
    );

    final n = chars.length;
    var columnCount = 1;
    while (columnCount < n &&
        fontFor((n / columnCount).ceil()) < _minColumnFont) {
      columnCount++;
    }

    final perColumn = (n / columnCount).ceil();
    var fontSize = fontFor(perColumn);
    var gap = fontSize * ratio;

    if (maxWidth != null) {
      final blockWidth = columnCount * fontSize + (columnCount - 1) * gap;
      if (blockWidth > maxWidth) {
        fontSize = maxWidth / (columnCount + ratio * (columnCount - 1));
        gap = fontSize * ratio;
      }
    }

    final columns = [
      for (var i = 0; i < n; i += perColumn)
        chars.sublist(i, (i + perColumn).clamp(0, n)),
    ];
    return (fontSize: fontSize, gap: gap, columns: columns);
  }
}
