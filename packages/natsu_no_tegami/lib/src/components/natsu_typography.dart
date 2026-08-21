import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 章节眉标 — kicker（Inter 小字 + 2px 字距）
///
/// 编辑排版语言：章节先给一个低调的欧文/日文眉标，再进正题。
class NatsuKicker extends StatelessWidget {
  const NatsuKicker(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: NatsuTypography.kicker);
  }
}

/// 章节标题 — heading（明朝 SemiBold）
class NatsuSectionHeading extends StatelessWidget {
  const NatsuSectionHeading(
    this.text, {
    super.key,
    this.level = NatsuHeadingLevel.h1,
  });

  final String text;

  final NatsuHeadingLevel level;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: switch (level) {
        NatsuHeadingLevel.display => NatsuTypography.display,
        NatsuHeadingLevel.h1 => NatsuTypography.heading,
        NatsuHeadingLevel.h2 => NatsuTypography.subheading,
      },
    );
  }
}

enum NatsuHeadingLevel { display, h1, h2 }

/// 邮戳式元数据行 — MetaLine
///
/// 信件的「地点 · 时间 · 天气」排版——匿名信唯一的语境锚点。
/// 这是排版语言而非图形邮戳：字距拉开的 Inter 小字，中点分隔，
/// 像信封上盖的一行信息。不做圆形邮戳图形（日式符号配给制）。
///
/// 「旅行是作品的一部分」由这行字的在场来传达。
class NatsuMetaLine extends StatelessWidget {
  const NatsuMetaLine({
    super.key,
    required this.items,
    this.align = NatsuMetaAlign.left,
  });

  /// 元数据项（地点/时间/天气…），按顺序以「 · 」连接。
  final List<String> items;

  final NatsuMetaAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      items.join(' · '),
      textAlign: switch (align) {
        NatsuMetaAlign.left => TextAlign.left,
        NatsuMetaAlign.right => TextAlign.right,
      },
      style: NatsuTypography.meta,
    );
  }
}

enum NatsuMetaAlign { left, right }
